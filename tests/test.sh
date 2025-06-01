#!/bin/bash
pr -m -t <(cat ./tests/test.txt) <(cat ./tests/test.txt | ./trad)
