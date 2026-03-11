.PHONY: test test-verbose test-agent-tools doc doc-clean setup deps clean lint

TEST_FILES ?= t/
AGENT_TOOLS_TEST ?= t/agent-tools/

test:
	prove -l $(TEST_FILES)

test-verbose:
	prove -lv $(TEST_FILES)

test-agent-tools:
	prove -l $(AGENT_TOOLS_TEST)

doc:
	@mkdir -p doc
	@for pod in $$(find lib -name '*.pm' -pod); do \
		base=$$(basename $$pod .pm); \
		pod2html --title="$$base" $$pod > doc/$$base.html 2>/dev/null || true; \
	done
	@echo "Documentation generated in doc/"

doc-clean:
	rm -rf doc/

deps:
	cpanm --installdeps .

setup: deps

lint:
	perl -Ilib -c $$($$(find lib -name '*.pm')) 2>&1 | grep -v "syntax OK" || true

tidy:
	perltidy -b $$(find lib t -name '*.pm' -type f)

tidy-dry:
	perltidy -st -se $$(find lib t -name '*.pm' -type f)

clean:
	rm -rf doc/ *.bak my.db

.DEFAULT_GOAL := test
