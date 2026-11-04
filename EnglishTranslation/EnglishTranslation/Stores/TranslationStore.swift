//
//  TranslationStore.swift
//  EnglishTranslation
//

import Foundation
import Observation

/// Holds the text the user typed and the result of translating it.
/// Created once in `EnglishTranslationApp` and shared with `.environment`.
@Observable
@MainActor
final class TranslationStore {
    var inputText = "" {
        didSet {
            guard inputText != oldValue else { return }
            // New text is the user's own until a caller says where it came from (TASK-128.3).
            source = baseSource
            schedulePrefetch()
        }
    }
    /// The language of the translation at the bottom of the result. Every change is saved (TASK-109),
    /// so the app, the extensions and Quick explain start with the language the learner picked.
    var targetLanguage: TargetLanguage {
        didSet { if targetLanguage != oldValue { languagePreference.language = targetLanguage } }
    }
    /// The language picker's value: the same as `targetLanguage`, but a change here is the learner's own pick, so it
    /// sends `language_changed` (TASK-128.3). A language that came from the account (`SettingsSync`) sends nothing.
    var pickedLanguage: TargetLanguage {
        get { targetLanguage }
        set {
            guard newValue != targetLanguage else { return }
            targetLanguage = newValue
            analytics.track(.languageChanged(language: newValue))
        }
    }
    private(set) var state: TranslationState = .idle
    /// While a sentence waits for Claude: the sentence, shown at once in its card (TASK-74, TASK-89.2).
    /// Nil at all other times.
    private(set) var pendingSentence: PendingSentence?
    /// True once the full `meaning` arrived. Late word-by-word pieces are then ignored (TASK-73).
    private var meaningIsFinal = false

    /// Text put in the input by another app (copied text, Share, the Mac Services item), trimmed (TASK-110).
    /// While the input still holds it, the result hides "Better way to say it": it is not the user's own English.
    /// Typing a change makes the text the user's.
    private var textFromElsewhere: String?

    /// The text whose request the server refused because the user is a guest (401 `sign_in_required`, TASK-70).
    /// Set when that happens, cleared by the next `translate()`. The extensions read it to say "Open Saynata to sign in".
    private(set) var textNeedingSignIn: String?
    /// True while the sign-in sheet is open over the result. Only the app's main screen opens it.
    var isSignInSheetOpen = false

    /// The pending cached-only prefetch (TASK-83.5). Replaced on each text change, cancelled when `translate()` starts.
    private var prefetchTask: Task<Void, Never>?
    /// How long the text must stay unchanged before the prefetch asks the server.
    private let prefetchDelay: Duration

    private let makeTranslator: @MainActor () throws -> any Translating
    private let makeWordLookup: @MainActor () throws -> any WordLooking
    /// Every final result is added here (TASK-93). Nil: no History.
    let history: (any HistoryStoring)?
    /// Where the picked language is saved.
    private let languagePreference: TargetLanguagePreference

    /// Where text typed in this store's input comes from: `.app` in the iPhone app, `.panel` on the Mac,
    /// `.share` or `.translateSheet` in the extensions (`lookup_done`, TASK-128.3).
    let baseSource: LookupSource
    /// Where the text in the input came from. Back to `baseSource` when the text changes.
    private(set) var source: LookupSource
    /// Usage events (`docs/analytics/events.md`). Never gets the text itself.
    @ObservationIgnored private let analytics: Analytics
    /// Tells `lookup_done` whether the language row starts open.
    @ObservationIgnored private let rowPreference: TranslationRowPreference

    /// - Parameter makeTranslator: Builds the translator on each request, so a
    ///   missing setting shows as a `.failed` state instead of crashing at launch.
    init(
        makeTranslator: @escaping @MainActor () throws -> any Translating = TranslatorFactory.makeTranslator,
        makeWordLookup: @escaping @MainActor () throws -> any WordLooking = TranslatorFactory.makeWordLookup,
        history: (any HistoryStoring)? = SyncedHistory.shared,
        prefetchDelay: Duration = .milliseconds(400),
        languagePreference: TargetLanguagePreference = .shared,
        source: LookupSource = .app,
        analytics: Analytics = .shared,
        rowPreference: TranslationRowPreference = TranslationRowPreference()
    ) {
        self.baseSource = source
        self.source = source
        self.analytics = analytics
        self.rowPreference = rowPreference
        self.languagePreference = languagePreference
        self.targetLanguage = languagePreference.language
        self.prefetchDelay = prefetchDelay
        self.makeTranslator = makeTranslator
        self.makeWordLookup = makeWordLookup
        self.history = history
    }

    /// The backend accepts 1 to 500 characters (`TranslationRequest.java`).
    static let maxInputLength = 500

    /// How many characters the backend will count. Java counts UTF-16 units, so an emoji is 2.
    /// Counting the same way means the app never allows text the backend would reject.
    var inputLength: Int {
        trimmedInput.utf16.count
    }

    /// True when the text is too long to send. The input shows "Make it shorter."
    var isOverLimit: Bool {
        inputLength > Self.maxInputLength
    }

    /// True when the button should be enabled.
    var canTranslate: Bool {
        if case .loading = state { return false }
        if case .meaning = state { return false } // still waiting for the rest of the answer
        return !trimmedInput.isEmpty && !isOverLimit
    }

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Handles `inputText` and updates `state`. One word (with or without an article, like "an apple") goes to the word lookup (a dictionary entry);
    /// 2 to 6 words that the cache knows as a phrase ("give up") show its word card (TASK-83.10);
    /// anything else goes to the backend as a sentence. Does nothing if `canTranslate` is false.
    func translate() async {
        guard canTranslate else { return }
        prefetchTask?.cancel()
        state = .loading
        textNeedingSignIn = nil
        if let word = CacheKeys.wordQuery(trimmedInput) {
            await lookUpWord(word)
        } else if let phrase = CacheKeys.phraseQuery(trimmedInput),
                  let entry = await (try? makeWordLookup())?.phraseEntry(for: phrase) {
            await showWord(entry, kind: .phrase)
        } else {
            await explainSentence()
        }
    }

    // MARK: - Prefetch while typing (TASK-83.5)

    /// After a pause in typing, asks the server for the answer it already has (cached only) and keeps it in the phone
    /// cache. Submit then finds it there and shows it at once, through the normal path (so History is written only on
    /// submit). Shows nothing, never calls Claude, never opens the sign-in sheet; a miss or an error is ignored.
    private func schedulePrefetch() {
        prefetchTask?.cancel()
        let text = trimmedInput
        guard !text.isEmpty, !isOverLimit else { return }
        let language = targetLanguage
        let delay = prefetchDelay
        prefetchTask = Task { [makeTranslator, makeWordLookup] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            if let word = CacheKeys.wordQuery(text) {
                await (try? makeWordLookup())?.prefetchCached(word)
                return
            }
            if let phrase = CacheKeys.phraseQuery(text) {
                await (try? makeWordLookup())?.prefetchCached(phrase)
                guard !Task.isCancelled else { return }
            }
            await (try? makeTranslator())?.prefetchCachedExplanation(text, translatingTo: language)
        }
    }

    private func lookUpWord(_ word: String) async {
        var lookup: (any WordLooking)?
        do {
            let wordLookup = try makeWordLookup()
            lookup = wordLookup
            let entry = try await wordLookup.lookUp(word)
            await showWord(entry, kind: .word)
            await addTermsToBundledWord(entry, typed: word, lookup: wordLookup)
        } catch BackendError.signInRequired {
            trackFailure(kind: .word, error: BackendError.signInRequired)
            askForSignIn(text: word)
        } catch WordLookupError.notAnEnglishWord {
            // The word list is incomplete, especially for compounds. Let the text explainer try before giving up.
            await explainSentence(afterMissingWord: (word, lookup))
        } catch {
            trackFailure(kind: .word, error: error)
            state = .failed(error.localizedDescription, spelling: spellingHelp(for: word, after: error, lookup: lookup))
        }
    }

    /// Shows a word or phrase card and adds it to History (TASK-93).
    private func showWord(_ entry: WordEntry, kind: LookupKind) async {
        state = .loadedWord(entry)
        trackLookup(kind: kind)
        await history?.record(SavedItem(entry: entry))
    }

    // MARK: - Usage events (TASK-128.3)

    /// `lookup_done` for the text in the input: its kind, where it came from and a length bucket, never the text.
    /// `text` and `source` are copied when the request starts; the user may type while it runs.
    private func trackLookup(kind: LookupKind, text: String? = nil, source: LookupSource? = nil) {
        analytics.track(.lookupDone(
            kind: kind, source: source ?? self.source, length: LengthBucket(text: text ?? trimmedInput),
            language: targetLanguage, rowStartsOpen: rowPreference.startsOpen))
    }

    private func trackFailure(kind: LookupKind, error: Error, source: LookupSource? = nil) {
        analytics.track(.lookupFailed(kind: kind, source: source ?? self.source, reason: LookupFailReason(error: error)))
    }

    /// A bundled word never asks the server, so its terms ("swift": Swift the language) come from `GET /api/terms`
    /// after the card is shown (TASK-119.6). They are added only if the same card is still on screen; offline or on
    /// an error nothing changes. History is not written again.
    private func addTermsToBundledWord(_ entry: WordEntry, typed word: String, lookup: any WordLooking) async {
        guard entry.terms == nil, lookup.bundledEntry(for: word) != nil else { return }
        let terms = await lookup.terms(for: word)
        guard !terms.isEmpty, case let .loadedWord(shown) = state, shown == entry else { return }
        state = .loadedWord(entry.withTerms(terms))
    }

    /// The word card for the English word or phrase the backend matched to non-English text (TASK-114).
    /// Nil on any error or an empty entry, so the caller shows the sentence result instead.
    private func wordCard(forMatch match: String) async -> WordEntry? {
        guard let entry = try? await makeWordLookup().lookUp(match), !entry.senses.isEmpty else { return nil }
        return entry
    }

    /// Close words to show under the error. Only when the backend says it is not an English word,
    /// or cannot be reached (`URLError`). The bundle was already checked before both.
    private func spellingHelp(for word: String, after error: Error, lookup: (any WordLooking)?) -> SpellingHelp? {
        guard let lookup else { return nil }
        var mayBeMisspelled = error is URLError
        if case .notAnEnglishWord = error as? WordLookupError { mayBeMisspelled = true }
        guard mayBeMisspelled else { return nil }

        let typedWord = CacheKeys.normalizeWord(word)
        let words = lookup.suggestions(for: typedWord)
        return words.isEmpty ? nil : SpellingHelp(typedWord: typedWord, suggestions: words)
    }

    /// The server said a guest cannot get this answer. Keep the text, show the message, and open the sign-in sheet.
    private func askForSignIn(text: String) {
        textNeedingSignIn = text
        state = .failed(BackendError.signInRequired.localizedDescription)
        isSignInSheetOpen = true
    }

    /// The user closed the sheet without signing in. The message stays in the result area.
    func cancelSignIn() {
        isSignInSheetOpen = false
    }

    /// The user signed in: close the sheet and run the original request again, so the result appears.
    /// Does nothing more when the sheet was opened from Settings (no request was waiting).
    func resumeAfterSignIn() async {
        isSignInSheetOpen = false
        guard let text = textNeedingSignIn else { return }
        inputText = text
        await translate()
    }

    /// Puts text from another app in the input, so its result does not offer a fix (TASK-110).
    /// - Parameter source: Where it came from, for `lookup_done`. Nil keeps `baseSource`.
    func useTextFromElsewhere(_ text: String, source: LookupSource? = nil) {
        inputText = text
        textFromElsewhere = trimmedInput
        if let source { self.source = source }
    }

    /// Puts text that another part of Saynata sent in the input, like the Share extension's "Open in Saynata" link.
    /// Unlike `useTextFromElsewhere`, the result may still offer a fix.
    func useText(_ text: String, from source: LookupSource) {
        inputText = text
        self.source = source
    }

    /// Back Tap opened the app (TASK-87, `CopiedTextLaunch`): copied text goes into the input and is explained.
    /// With nothing copied, or the paste not allowed, the input and the result are cleared instead.
    /// - Returns: true when the input is empty, so the screen gives it the keyboard.
    @discardableResult
    func startFromClipboard(_ clipboard: any ClipboardReading) async -> Bool {
        // A sign-in sheet left open from the last text would cover the new start.
        isSignInSheetOpen = false
        if case let .text(copied) = await clipboard.content() {
            let cleaned = CopiedText.cleaned(copied)
            if !cleaned.isEmpty {
                useTextFromElsewhere(cleaned, source: .copied)
                await translate()
                return false
            }
        }
        inputText = ""
        state = .idle
        textNeedingSignIn = nil
        return true
    }

    /// The user picked another language on the result (share and translation sheet). It becomes the picked language
    /// everywhere, like the app's picker. A word card follows it at once; a sentence is asked again, so its language
    /// line comes in the new language (the English part is a cache hit).
    func changeLanguage(to language: TargetLanguage) async {
        guard language != targetLanguage else { return }
        targetLanguage = language
        analytics.track(.languageChanged(language: language))
        if case .loaded = state {
            await translate()
        }
    }

    /// The user tapped a "did you mean" word: put it in the input and look it up.
    func lookUp(suggestion word: String) async {
        analytics.track(.suggestionTapped)
        inputText = word
        await translate()
    }

    /// The full word card for a word in a sentence result. Uses the bundled entry when there is one,
    /// otherwise the normal lookup (local cache, then backend). The sentence result stays on screen.
    func wordEntry(for word: SentenceWordInfo) async throws -> WordEntry {
        analytics.track(.sentenceWordOpened(hasEntry: word.entry != nil))
        if let entry = word.entry { return entry }
        return try await makeWordLookup().lookUp(word.word)
    }

    /// Adds the next characters of the meaning (TASK-73), so the text grows on screen.
    /// Ignored once the full meaning is there, and when the request is no longer running.
    private func appendToMeaning(_ piece: String, sentence: String, language: TargetLanguage) {
        guard !meaningIsFinal else { return }
        switch state {
        case .loading:
            state = .meaning(SentenceMeaning(sentence: sentence, meaning: piece, language: language))
        case let .meaning(current):
            state = .meaning(SentenceMeaning(sentence: sentence, meaning: current.meaning + piece, language: language))
        case .idle, .loaded, .loadedWord, .failed:
            break
        }
    }

    /// Shows the full meaning. It replaces any text built from pieces, so a missing or late piece never matters.
    /// Only while the request is still running.
    private func showMeaning(_ meaning: SentenceMeaning) {
        meaningIsFinal = true
        switch state {
        case .loading, .meaning: state = .meaning(meaning)
        case .idle, .loaded, .loadedWord, .failed: break
        }
    }

    private func explainSentence(afterMissingWord: (text: String, lookup: (any WordLooking)?)? = nil) async {
        // Copy these first. The user can change the picker or the text while we wait.
        let sentence = trimmedInput
        let language = targetLanguage
        let source = self.source
        meaningIsFinal = false
        pendingSentence = PendingSentence(sentence: sentence, language: language)
        // Loaded or failed: the loading card goes.
        defer { pendingSentence = nil }
        do {
            let translator = try makeTranslator()
            let explanation = try await translator.explainWithFallback(
                sentence,
                language: language,
                onMeaningDelta: { [weak self] piece in
                    self?.appendToMeaning(piece, sentence: sentence, language: language)
                },
                onMeaning: { [weak self] meaning in
                    self?.showMeaning(SentenceMeaning(sentence: sentence, meaning: meaning, language: language))
                })
            // One non-English word or idiom ("buồn"): open the normal word card. Any failure keeps the sentence result.
            if let match = explanation.wordMatchQuery, let entry = await wordCard(forMatch: match) {
                await showWord(entry, kind: .word)
                return
            }
            let result = SentenceResult(
                sentence: sentence, explanation: explanation, language: language, isTyped: sentence != textFromElsewhere)
            state = .loaded(result)
            trackLookup(kind: .sentence, text: sentence, source: source)
            await history?.record(SavedItem(result: result))
        } catch BackendError.signInRequired {
            trackFailure(kind: .sentence, error: BackendError.signInRequired, source: source)
            askForSignIn(text: sentence)
        } catch {
            trackFailure(kind: .sentence, error: error, source: source)
            let spelling = afterMissingWord.flatMap { missing in
                spellingHelp(for: missing.text, after: WordLookupError.notAnEnglishWord(missing.text), lookup: missing.lookup)
            }
            state = .failed(error.localizedDescription, spelling: spelling)
        }
    }
}
