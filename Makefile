# If you change something here, be sure to reflect the changes in:
# - the scripts section of the package.json file
# - the .travis.yml file

# -----------------
# Variables

BIN=node_modules/.bin/
COFFEE=$(BIN)coffee


# -----------------
# Documentation

# Usage: coffee [options] path/to/script.coffee -- [args]
# -b, --bare         compile without a top-level function wrapper
# -c, --compile      compile to JavaScript and save as .js files
# -o, --output       set the output directory for compiled JavaScript
# -w, --watch        watch scripts for changes and rerun commands


# -----------------
# Commands

# Watch and recompile our files
dev:
	$(COFFEE) -cbwo out src

# Compile our files
compile:
	$(COFFEE) -cbo out src

# Clean up
clean:
	rm -Rf out node_modules npm-debug.log

# Install dependencies
install:
	npm install

# Reset
reset:
	make clean
	make install

# Install dependencies
install:
	npm install

# Ensure everything is ready for our tests (used by things like travis)
test-prepare:
	make install
	make compile

# Run our tests
test:
	npm test

# Ensure the listed commands always re-run and are never cached
.PHONY: dev compile clean install reset test-prepare test