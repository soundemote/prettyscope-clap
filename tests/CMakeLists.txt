add_executable(${PROJECT_NAME}-tests test_main.cpp dsp_basics.cpp)
target_link_libraries(${PROJECT_NAME}-tests
        ${PROJECT_NAME}-impl
        fmt-header-only
        clap
        simde
        sst-basic-blocks
        sst-cpputils
        sst-voicemanager
        sst-plugininfra
        sst-plugininfra::filesystem
        sst-plugininfra::tinyxml
        sst-plugininfra::strnatcmp
        sst-plugininfra::patchbase
        sst-plugininfra::version_information
        catch2)
