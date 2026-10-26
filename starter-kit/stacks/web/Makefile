.PHONY: check test dev
check:   ## what CI runs
	npm run lint && npm run format:check && npm run typecheck && npm test && npm run build
test:    ## one file: make test F=src/features/notes/NotesPage.test.tsx
	npx vitest run $(F)
dev:
	npm run dev
