import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { server } from '@/test/server'
import { renderWithProviders } from '@/test/render'
import { NotesPage } from './NotesPage'

const note = { id: 1, title: 'First', body: null, createdAt: '2026-01-01T00:00:00Z' }

test('shows the notes from the API', async () => {
  server.use(http.get('/api/v1/notes', () => HttpResponse.json([note])))

  renderWithProviders(<NotesPage />)

  expect(await screen.findByText('First')).toBeInTheDocument()
})

test('shows the field error when the API rejects the title', async () => {
  server.use(
    http.get('/api/v1/notes', () => HttpResponse.json([])),
    http.post('/api/v1/notes', () =>
      HttpResponse.json(
        {
          code: 'validation_failed',
          detail: 'Invalid request',
          fields: { title: 'must not be blank' },
        },
        { status: 400 },
      ),
    ),
  )
  renderWithProviders(<NotesPage />)

  await userEvent.type(screen.getByLabelText('Title'), ' ')
  await userEvent.click(screen.getByRole('button', { name: 'Add' }))

  expect(await screen.findByRole('alert')).toHaveTextContent('must not be blank')
})
