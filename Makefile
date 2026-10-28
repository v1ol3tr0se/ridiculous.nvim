STYLUA ?= stylua
NVIM ?= nvim
SPECS := $(wildcard tests/*_spec.lua)

.PHONY: verify format

verify:
	$(STYLUA) --check .
	for f in $(SPECS); do $(NVIM) --headless --clean -u tests/minimal_init.lua -l "$$f" || exit 1; echo "ok $$f"; done

format:
	$(STYLUA) .
