
dependencies: dependencies.json
	@packin install --folder $@ --meta $<
	@ln -snf .. $@/router

test: dependencies
	@$</jest/bin/jest test

.PHONY: test
