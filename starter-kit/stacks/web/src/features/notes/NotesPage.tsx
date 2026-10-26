import { useState, type FormEvent } from 'react'
import { ApiError } from '@/lib/api-client'
import { track } from '@/lib/analytics'
import { useCreateNote, useNotes } from './api'

export function NotesPage() {
  const notes = useNotes()
  const createNote = useCreateNote()
  const [title, setTitle] = useState('')

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    createNote.mutate(
      { title },
      {
        onSuccess: (note) => {
          track('note_created', { title_length: note.title.length })
          setTitle('')
        },
      },
    )
  }

  const error = createNote.error instanceof ApiError ? createNote.error : null

  return (
    <main>
      <h1>Notes</h1>
      <form onSubmit={onSubmit}>
        <label>
          Title <input value={title} onChange={(e) => setTitle(e.target.value)} />
        </label>
        <button type="submit" disabled={createNote.isPending}>
          Add
        </button>
        {error && <p role="alert">{error.fields?.title ?? error.message}</p>}
      </form>

      {notes.isPending && <p>Loading…</p>}
      {notes.isError && <p role="alert">Could not load notes.</p>}
      <ul>
        {notes.data?.map((note) => (
          <li key={note.id}>{note.title}</li>
        ))}
      </ul>
    </main>
  )
}
