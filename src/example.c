#include <crc32c/crc32c.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

int main(int argc, char** argv) {
    if (argc == 1) {
        fprintf(stderr, "1st arg(text) is required.\nThis will print the crc32c checksum of the args.\n");  
        return 0;
    }
    char* arg;
    size_t len;
    uint32_t result = 0;
    for (int i = 1; i < argc; i++) {
        arg = argv[i];
        len = strlen(arg);
        result = crc32c_extend(result, (const uint8_t*)arg, len);
    }
    
    fprintf(stderr, "%" PRIu32 "\n", result);
    return 0;
}
