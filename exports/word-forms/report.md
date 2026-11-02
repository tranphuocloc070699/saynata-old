# Word forms report

Input: 51,787 existing entries (42,660 single words, 9,127 phrases).

## word_forms.tsv

| | Rows |
|---|---|
| all (form, lemma) pairs | 44,899 |
| from single words | 27,871 |
| from phrases (first word inflected) | 17,028 |
| distinct forms not yet in the DB | 38,835 |
| dropped: not in scowl-70 / zipf | 2,634 |

| form_type | Rows |
|---|---|
| past tense | 11,113 |
| -ing form | 11,075 |
| plural | 8,929 |
| third person | 8,289 |
| form | 3,074 |
| past participle | 1,061 |
| superlative | 680 |
| comparative | 678 |

## form_entries.tsv (existing words that are a form of another existing word)

| status | Words | Meaning |
|---|---|---|
| pure form | 4,867 | only a form (e.g. contaminated): merge into the lemma |
| own meaning too | 1,098 | also a word of its own (e.g. glasses): review |

Most common pure forms: is → be, was → be, are → be, has → have, were → be, had → have, been → be, would → will, could → can, said → say, should → shall, did → do, years → year, made → make, got → get

Most common 'own meaning too': more → much, most → much, being → be, going → go, best → good,well, used → use, better → good,well, things → thing, found → find, left → leave, number → numb, doing → do, thought → think, done → do, based → base
