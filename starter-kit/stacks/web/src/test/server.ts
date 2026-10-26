import { setupServer } from 'msw/node'

// Fake API for tests. Each test adds the handlers it needs with server.use(...).
export const server = setupServer()
