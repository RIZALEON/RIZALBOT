#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <mutex>
#include <algorithm>

#include "llama.h"

#define LOG_TAG "yabot_llama"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static std::mutex g_mu;
static llama_model * g_model = nullptr;
static llama_context * g_ctx = nullptr;
static llama_sampler * g_smpl = nullptr;
static std::string g_err;

static void set_err(const std::string & e) {
    g_err = e;
    ALOGE("%s", e.c_str());
}

static void free_all_unlocked() {
    if (g_smpl) { llama_sampler_free(g_smpl); g_smpl = nullptr; }
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_io_github_rizaleon_abomega_LlamaBridge_nativeLoad(JNIEnv * env, jclass, jstring jpath) {
    std::lock_guard<std::mutex> lock(g_mu);
    const char * path = env->GetStringUTFChars(jpath, nullptr);
    std::string path_str = path ? path : "";
    env->ReleaseStringUTFChars(jpath, path);

    free_all_unlocked();
    llama_backend_init();

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0;
    g_model = llama_model_load_from_file(path_str.c_str(), mparams);
    if (!g_model) {
        set_err("llama_model_load_from_file failed: " + path_str);
        return JNI_FALSE;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = 512;
    cparams.n_batch = 64;
    cparams.n_threads = 4;
    cparams.n_threads_batch = 4;
    g_ctx = llama_init_from_model(g_model, cparams);
    if (!g_ctx) {
        set_err("llama_init_from_model failed");
        free_all_unlocked();
        return JNI_FALSE;
    }

    auto sparams = llama_sampler_chain_default_params();
    g_smpl = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_smpl, llama_sampler_init_greedy());

    g_err.clear();
    ALOGI("model loaded: %s", path_str.c_str());
    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_io_github_rizaleon_abomega_LlamaBridge_nativeGenerate(JNIEnv * env, jclass, jstring jprompt, jint n_predict) {
    std::lock_guard<std::mutex> lock(g_mu);
    if (!g_model || !g_ctx || !g_smpl) {
        set_err("model not loaded");
        return env->NewStringUTF("");
    }
    const char * prompt_c = env->GetStringUTFChars(jprompt, nullptr);
    std::string prompt = prompt_c ? prompt_c : "";
    env->ReleaseStringUTFChars(jprompt, prompt_c);

    const llama_vocab * vocab = llama_model_get_vocab(g_model);
    const int n_prompt = -llama_tokenize(vocab, prompt.c_str(), (int)prompt.size(), nullptr, 0, true, true);
    if (n_prompt <= 0) {
        set_err("tokenize failed");
        return env->NewStringUTF("");
    }
    std::vector<llama_token> prompt_tokens((size_t)n_prompt);
    if (llama_tokenize(vocab, prompt.c_str(), (int)prompt.size(), prompt_tokens.data(), (int)prompt_tokens.size(), true, true) < 0) {
        set_err("tokenize fill failed");
        return env->NewStringUTF("");
    }

    llama_memory_clear(llama_get_memory(g_ctx), true);
    llama_sampler_reset(g_smpl);

    int max_new = n_predict > 0 ? std::min((int)n_predict, 16) : 16;
    // Ensure room in ctx
    if (n_prompt + max_new >= (int)llama_n_ctx(g_ctx)) {
        max_new = (int)llama_n_ctx(g_ctx) - n_prompt - 1;
        if (max_new < 1) {
            set_err("prompt too long for n_ctx");
            return env->NewStringUTF("");
        }
    }

    std::string out;
    int n_decode = 0;
    llama_token new_token_id = 0;

    ALOGI("generate start prompt_tokens=%d max_new=%d", n_prompt, max_new);

    // Chunk prompt decode so emu can make progress / log
    const int chunk = 8;
    for (int i = 0; i < n_prompt; i += chunk) {
        int n = std::min(chunk, n_prompt - i);
        llama_batch batch = llama_batch_get_one(prompt_tokens.data() + i, n);
        ALOGI("decode prompt [%d..%d)", i, i + n);
        if (llama_decode(g_ctx, batch) != 0) {
            set_err("llama_decode prompt failed");
            return env->NewStringUTF("");
        }
    }

    for (int i = 0; i < max_new; ++i) {
        new_token_id = llama_sampler_sample(g_smpl, g_ctx, -1);
        if (llama_vocab_is_eog(vocab, new_token_id)) break;
        char buf[256];
        int n = llama_token_to_piece(vocab, new_token_id, buf, sizeof(buf), 0, true);
        if (n > 0) out.append(buf, n);
        llama_batch batch = llama_batch_get_one(&new_token_id, 1);
        ALOGI("decode gen token %d", i);
        if (llama_decode(g_ctx, batch) != 0) {
            set_err("llama_decode gen failed");
            break;
        }
        n_decode += 1;
    }
    ALOGI("generate done tokens=%d chars=%zu", n_decode, out.size());
    return env->NewStringUTF(out.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_io_github_rizaleon_abomega_LlamaBridge_nativeLastError(JNIEnv * env, jclass) {
    return env->NewStringUTF(g_err.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_io_github_rizaleon_abomega_LlamaBridge_nativeUnload(JNIEnv *, jclass) {
    std::lock_guard<std::mutex> lock(g_mu);
    free_all_unlocked();
}
