#include <crc32c/crc32c.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

int main(int argc, char** argv) {
    if (argc == 1) {
        printf("1st arg is required.\n");  
        return 1;
    }
    char* arg = argv[1];
    size_t len = strlen(arg);
    
    const uint32_t result = crc32c_value((const uint8_t*)arg, len);
    
    printf("%" PRIu32 "\n", result);
    return 0;
}
