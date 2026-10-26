import { createBrowserRouter } from 'react-router'
import { NotesPage } from '@/features/notes/NotesPage'

export const router = createBrowserRouter([
  { path: '/', element: <NotesPage /> },
  { path: '*', element: <p>Page not found.</p> },
])
