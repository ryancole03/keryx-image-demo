#include <windows.h>

#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using AbiFn = int (*)();
using LoadFn = void* (*)(const char*);
using CountFn = size_t (*)(void*);
using InfoFn = int (*)(void*, size_t, const char**, const void**, size_t*, int*);
using GenerateFn = int (*)(void*, const char*, int, int64_t, uint8_t*, size_t);
using FreeFn = void (*)(void*);

struct TensorInfo {
    std::string name;
    const void* data;
    size_t nbytes;
    int is_device;
};

template <typename T>
T symbol(HMODULE library, const char* name) {
    auto value = reinterpret_cast<T>(GetProcAddress(library, name));
    if (value == nullptr) {
        std::cerr << "missing symbol: " << name << '\n';
        std::exit(1);
    }
    return value;
}

int main(int argc, char** argv) {
    if (argc != 4) {
        std::cerr << "usage: sd_zerocopy_spike <stable-diffusion.dll> <model.gguf> <output.ppm>\n";
        return 2;
    }

    HMODULE library = LoadLibraryA(argv[1]);
    if (library == nullptr) {
        std::cerr << "failed to load DLL: " << GetLastError() << '\n';
        return 1;
    }
    auto abi = symbol<AbiFn>(library, "keryx_sd_abi");
    auto load = symbol<LoadFn>(library, "keryx_sd_load");
    auto count = symbol<CountFn>(library, "keryx_sd_tensor_count");
    auto info = symbol<InfoFn>(library, "keryx_sd_tensor_info");
    auto generate = symbol<GenerateFn>(library, "keryx_sd_generate");
    auto free_model = symbol<FreeFn>(library, "keryx_sd_free");
    if (abi() != 1) {
        std::cerr << "unsupported ABI\n";
        return 1;
    }

    void* model = load(argv[2]);
    if (model == nullptr) {
        std::cerr << "model load failed\n";
        return 1;
    }
    std::vector<TensorInfo> before;
    size_t device_bytes = 0;
    size_t host_bytes = 0;
    for (size_t i = 0; i < count(model); ++i) {
        const char* name = nullptr;
        const void* data = nullptr;
        size_t nbytes = 0;
        int is_device = 0;
        if (!info(model, i, &name, &data, &nbytes, &is_device)) {
            std::cerr << "tensor enumeration failed at " << i << '\n';
            free_model(model);
            return 1;
        }
        before.push_back({name, data, nbytes, is_device});
        (is_device ? device_bytes : host_bytes) += nbytes;
    }
    if (before.empty() || device_bytes == 0) {
        std::cerr << "no resident CUDA tensors\n";
        free_model(model);
        return 1;
    }

    std::vector<uint8_t> rgb(512 * 512 * 3);
    if (!generate(model, "a small red sailboat on calm water", 4, 42, rgb.data(), rgb.size())) {
        std::cerr << "image generation failed\n";
        free_model(model);
        return 1;
    }
    if (count(model) != before.size()) {
        std::cerr << "resident tensor count changed after generation\n";
        free_model(model);
        return 1;
    }
    for (size_t i = 0; i < before.size(); ++i) {
        const char* name = nullptr;
        const void* data = nullptr;
        size_t nbytes = 0;
        int is_device = 0;
        if (!info(model, i, &name, &data, &nbytes, &is_device) || before[i].name != name ||
            before[i].data != data || before[i].nbytes != nbytes || before[i].is_device != is_device) {
            std::cerr << "resident tensor changed after generation at " << i << '\n';
            free_model(model);
            return 1;
        }
    }

    std::ofstream output(argv[3], std::ios::binary);
    output << "P6\n512 512\n255\n";
    output.write(reinterpret_cast<const char*>(rgb.data()), rgb.size());
    std::ofstream manifest(std::string(argv[3]) + ".tensors");
    for (const auto& tensor : before) {
        manifest << tensor.name << '\t' << tensor.nbytes << '\n';
    }
    free_model(model);
    FreeLibrary(library);
    if (!output || !manifest) {
        std::cerr << "failed to write verification artifacts\n";
        return 1;
    }
    std::cout << "PASS tensors=" << before.size() << " device_bytes=" << device_bytes
              << " host_bytes=" << host_bytes << " pointers_unchanged=true\n";
    return 0;
}
