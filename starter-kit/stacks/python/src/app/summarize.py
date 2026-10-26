"""Example feature: summarize a text in plain English. Shows how a feature uses the LLM wrapper."""

from pydantic import BaseModel, Field

from app.llm import LLM, Prompt

SUMMARY_PROMPT = Prompt(
    name="summarize",
    version=1,
    system=(
        "You summarize texts for English learners at B1-B2 level. "
        "Use short sentences and common words. Keep names and numbers exact."
    ),
)


class Summary(BaseModel):
    summary: str = Field(description="Two or three short sentences.")
    key_words: list[str] = Field(description="Up to five useful words from the text.")


def summarize(llm: LLM, text: str) -> Summary:
    return llm.ask(SUMMARY_PROMPT, f"<text>\n{text}\n</text>", Summary, max_tokens=2_000)
