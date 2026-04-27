#!/bin/bash
./tester | tee run.tester.log
cp ../sim/tmpdir/run.vcs.log  .
