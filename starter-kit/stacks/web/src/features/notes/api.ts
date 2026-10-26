import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api-client'

// Mirrors the backend's NoteResponse. (Later: generate these from /v3/api-docs with openapi-typescript.)
export type Note = { id: number; title: string; body: string | null; createdAt: string }
export type NewNote = { title: string; body?: string }

const keys = { all: ['notes'] as const }

export function useNotes() {
  return useQuery({ queryKey: keys.all, queryFn: () => api<Note[]>('/api/v1/notes') })
}

export function useCreateNote() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (note: NewNote) =>
      api<Note>('/api/v1/notes', { method: 'POST', body: JSON.stringify(note) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: keys.all }),
  })
}
