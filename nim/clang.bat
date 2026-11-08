@echo off
zig cc -std=gnu11 -Wno-unsafe-buffer-usage %*
