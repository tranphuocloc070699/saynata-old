# Word forms report

Input: 46,809 existing entries (37,682 single words, 9,127 phrases).

## word_forms.tsv

| | Rows |
|---|---|
| all (form, lemma) pairs | 43,278 |
| from single words | 26,250 |
| from phrases (first word inflected) | 17,028 |
| distinct forms not yet in the DB | 37,323 |
| dropped: not in scowl-70 / zipf | 2,397 |

| form_type | Rows |
|---|---|
| past tense | 10,813 |
| -ing form | 10,779 |
| plural | 8,289 |
| third person | 8,088 |
| form | 2,967 |
| past participle | 1,060 |
| superlative | 642 |
| comparative | 640 |

## form_entries.tsv (existing words that are a form of another existing word)

| status | Words | Meaning |
|---|---|---|
| pure form | 4,808 | only a form (e.g. contaminated): merge into the lemma |
| own meaning too | 1,050 | also a word of its own (e.g. glasses): review |

Most common pure forms: is → be, was → be, are → be, has → have, were → be, had → have, been → be, would → will, could → can, said → say, should → shall, did → do, years → year, made → make, got → get

Most common 'own meaning too': more → much, most → much, being → be, going → go, best → good,well, used → use, better → good,well, things → thing, found → find, left → leave, number → numb, doing → do, thought → think, done → do, based → base
