-include .env

.PHONY: build test

build:
	forge build

test:
	forge test