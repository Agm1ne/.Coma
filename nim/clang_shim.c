#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(int argc, char** argv) {
    char cmd[8192];
    strcpy(cmd, "zig cc ");
    for (int i = 1; i < argc; i++) {
        strcat(cmd, argv[i]);
        strcat(cmd, " ");
    }
    fflush(stdout);
    fflush(stderr);
    int ret = system(cmd);
    return ret;
}
