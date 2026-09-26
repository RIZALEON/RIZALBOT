plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// llama.cpp checkout for the native Heart bridge. Mac default unchanged; CI passes -PyabotLlamaDir or YABOT_LLAMA_DIR.
val yabotLlamaDir: String = (project.findProperty("yabotLlamaDir") as String?)
    ?: System.getenv("YABOT_LLAMA_DIR")
    ?: "/Users/rizal/Library/Developer/ya-deps/llama.cpp"

android {
    namespace = "io.github.rizaleon.abomega"
    compileSdk = 35
    ndkVersion = "27.2.12479018"

    defaultConfig {
        applicationId = "io.github.rizaleon.abomega"
        minSdk = 26
        targetSdk = 35
        versionCode = 5
        versionName = "0.3.3"
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
        externalNativeBuild {
            cmake {
                cppFlags += "-O3 -std=c++17"
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DBUILD_SHARED_LIBS=OFF",
                    "-DLLAMA_BUILD_TESTS=OFF",
                    "-DLLAMA_BUILD_EXAMPLES=OFF",
                    "-DLLAMA_BUILD_TOOLS=OFF",
                    "-DLLAMA_BUILD_SERVER=OFF",
                    "-DGGML_NATIVE=OFF",
                    "-DGGML_BLAS=OFF",
                    "-DGGML_OPENMP=OFF",
                    "-DYABOT_LLAMA_DIR=$yabotLlamaDir"
                )
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = false
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
}
