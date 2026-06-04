/*
 * Prettyscope CLAP
 *
 * Copyright 2026, Soundemote.
 *
 * Adapted from the standalone Prettyscope renderer files in
 * C:\Users\argit\Documents\_PROGRAMMING\prettyscope\src\visual:
 * scope_renderer, beam_renderer, persistence_buffer, screen_quad, shaders,
 * and gl_utils. This plugin version keeps the golden phosphor beam/decay math
 * while adapting ownership and inputs to the JUCE OpenGL renderer slot.
 */

#include "phosphor-scope-renderer.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace baconpaul::sidequest_ns::ui
{
namespace
{
using GlId = unsigned int;

struct RgbColor
{
    float r{};
    float g{};
    float b{};
};

struct Point
{
    float x{};
    float y{};
};

struct BeamVertex
{
    float startX{};
    float startY{};
    float endX{};
    float endY{};
    float corner{};
};

struct DotPointVertex
{
    float x{};
    float y{};
};

struct SignalBuffer
{
    std::vector<float> left;
    std::vector<float> right;
    uint64_t lastSnapshotSerial{std::numeric_limits<uint64_t>::max()};
    float lastTimeScale{};

    void append(const ScopeAudioSnapshot &snapshot, float timeScale, uint64_t snapshotSerial)
    {
        const auto clampedScale = std::clamp(timeScale, 0.25f, 4.0f);
        if (std::abs(clampedScale - lastTimeScale) > 0.001f)
        {
            left.clear();
            right.clear();
            lastTimeScale = clampedScale;
        }

        if (snapshotSerial == lastSnapshotSerial)
        {
            return;
        }
        lastSnapshotSerial = snapshotSerial;

        const auto sourceFrames = snapshot.validFrameCount();
        if (!snapshot.hasRenderableTrace() || sourceFrames < 2)
        {
            left.clear();
            right.clear();
            return;
        }

        const auto step = std::max<uint32_t>(1, static_cast<uint32_t>(std::round(clampedScale)));
        for (uint32_t i = 0; i < sourceFrames; i += step)
        {
            left.push_back(snapshot.samples[0][i]);
            right.push_back(snapshot.samples[1][i]);
        }

        constexpr size_t maxVisualFrames = 2048;
        if (left.size() > maxVisualFrames)
        {
            const auto removeCount = left.size() - maxVisualFrames;
            left.erase(left.begin(), left.begin() + static_cast<ptrdiff_t>(removeCount));
            right.erase(right.begin(), right.begin() + static_cast<ptrdiff_t>(removeCount));
        }
    }

    bool renderable() const { return left.size() > 1 && right.size() == left.size(); }
    size_t size() const { return left.size(); }
    float l(size_t index) const { return left[index]; }
    float r(size_t index) const { return right[index]; }
};

struct PhosphorParams
{
    RgbColor backgroundColor{0.018f, 0.012f, 0.026f};
    RgbColor traceColor{1.0f, 0.22f, 0.70f};
    RgbColor glowColor{0.18f, 0.80f, 1.0f};
    float traceGain{0.10f};
    float coreIntensity{1.15f};
    float coreWidth{2.0f};
    float glowIntensity{0.35f};
    float glowWidth{7.0f};
    float persistence{0.98f};
    float fastDecay{0.25f};
    float afterglow{0.95f};
    float floorFade{0.00035f};
    int clearRevision{0};
};

constexpr const char *kBeamVertex = R"GLSL(
#version 150

in vec2 segmentStart;
in vec2 segmentEnd;
in float cornerIndex;

uniform vec2 viewportSize;
uniform float beamSize;

out vec3 beamFrame;

void main()
{
    vec2 startPx = (segmentStart * 0.5 + 0.5) * viewportSize;
    vec2 endPx = (segmentEnd * 0.5 + 0.5) * viewportSize;
    vec2 dir = endPx - startPx;
    float len = length(dir);

    if (len > 0.0001) {
        dir /= len;
    } else {
        dir = vec2(1.0, 0.0);
    }

    vec2 norm = vec2(-dir.y, dir.x);
    float idx = mod(cornerIndex, 4.0);
    float side = (mod(idx, 2.0) - 0.5) * 2.0;
    float tang;
    vec2 current;

    if (idx >= 2.0) {
        current = endPx;
        tang = 1.0;
        beamFrame.x = -beamSize;
    } else {
        current = startPx;
        tang = -1.0;
        beamFrame.x = len + beamSize;
    }

    beamFrame.y = side * beamSize;
    beamFrame.z = len;

    vec2 positionPx = current + (tang * dir + side * norm) * beamSize;
    vec2 clip = positionPx / viewportSize * 2.0 - 1.0;
    gl_Position = vec4(clip, 0.0, 1.0);
}
)GLSL";

constexpr const char *kBeamFragment = R"GLSL(
#version 150

#define EPS 1e-6
#define SQRT2 1.4142135623730951

uniform vec3 beamColor;
uniform float beamSize;
uniform float beamIntensity;

in vec3 beamFrame;

out vec4 fragColor;

float erfApprox(float x)
{
    float s = sign(x);
    float a = abs(x);
    float b = 1.0 + (0.278393 + (0.230389 + 0.078108 * a * a) * a) * a;
    b *= b;
    return s - s / (b * b);
}

void main()
{
    float len = beamFrame.z;
    float sigma = max(beamSize * 0.25, 0.001);
    float alpha;

    if (len < EPS) {
        alpha = exp(-dot(beamFrame.xy, beamFrame.xy) / (2.0 * sigma * sigma)) / max(2.0 * sqrt(beamSize), 1.0);
    } else {
        alpha = erfApprox(beamFrame.x / (SQRT2 * sigma)) - erfApprox((beamFrame.x - len) / (SQRT2 * sigma));
        alpha *= exp(-beamFrame.y * beamFrame.y / (2.0 * sigma * sigma)) * beamSize / (2.0 * len);
    }

    alpha = clamp(alpha * beamIntensity, 0.0, 1.0);
    fragColor = vec4(beamColor, alpha);
}
)GLSL";

constexpr const char *kScreenVertex = R"GLSL(
#version 150

in vec2 position;
in vec2 texcoord;
out vec2 uv;

void main()
{
    uv = texcoord;
    gl_Position = vec4(position, 0.0, 1.0);
}
)GLSL";

constexpr const char *kTextureFragment = R"GLSL(
#version 150

in vec2 uv;
out vec4 fragColor;

uniform sampler2D image;

void main()
{
    fragColor = texture(image, uv);
}
)GLSL";

constexpr const char *kDotImageVertex = R"GLSL(
#version 150

in vec2 dotPosition;
uniform vec2 viewportSize;
uniform float pointSize;

void main()
{
    gl_Position = vec4(dotPosition, 0.0, 1.0);
    gl_PointSize = pointSize;
}
)GLSL";

constexpr const char *kDotImageFragment = R"GLSL(
#version 150

uniform sampler2D dotTexture;
uniform float intensity;
uniform float imageMix;

out vec4 fragColor;

void main()
{
    vec4 texel = texture(dotTexture, gl_PointCoord);
    fragColor = vec4(texel.rgb * intensity, texel.a * imageMix);
}
)GLSL";

constexpr const char *kDecayFragment = R"GLSL(
#version 150

in vec2 uv;
out vec4 fragColor;

uniform sampler2D image;
uniform vec3 backgroundColor;
uniform float persistence;
uniform float fastDecay;
uniform float afterglow;
uniform float floorFade;

void main()
{
    vec3 src = texture(image, uv).rgb;
    vec3 signal = max(src - backgroundColor, vec3(0.0));
    float brightness = max(max(signal.r, signal.g), signal.b);
    float dimTail = 1.0 - smoothstep(0.015, 0.34, brightness);
    float softTail = 1.0 - smoothstep(0.18, 0.82, brightness);
    float brightDrain = brightness * mix(0.035, 0.24, fastDecay);
    float tailBoost = dimTail * mix(0.0, 0.055, afterglow) + softTail * afterglow * 0.012;
    float keep = clamp(persistence + tailBoost - brightDrain, 0.0, mix(0.982, 0.9975, afterglow));
    signal *= keep;
    signal = max(signal - vec3(floorFade), vec3(0.0));
    signal = pow(signal, vec3(mix(1.035, 1.012, afterglow)));
    fragColor = vec4(backgroundColor + signal, 1.0);
}
)GLSL";

GlId compileShader(unsigned int type, const char *source)
{
    using namespace juce::gl;

    const GlId shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    int success = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (success == GL_FALSE)
    {
        char log[1024] = {};
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        glDeleteShader(shader);
        throw std::runtime_error(std::string("OpenGL shader compile failed: ") + log);
    }

    return shader;
}

GlId createProgram(const char *vertexSource, const char *fragmentSource)
{
    using namespace juce::gl;

    const GlId vertexShader = compileShader(GL_VERTEX_SHADER, vertexSource);
    const GlId fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentSource);
    const GlId program = glCreateProgram();

    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glBindAttribLocation(program, 0, "position");
    glBindAttribLocation(program, 1, "texcoord");
    glBindAttribLocation(program, 1, "segmentStart");
    glBindAttribLocation(program, 2, "segmentDelta");
    glLinkProgram(program);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    int success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (success == GL_FALSE)
    {
        char log[1024] = {};
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        glDeleteProgram(program);
        throw std::runtime_error(std::string("OpenGL shader link failed: ") + log);
    }

    return program;
}

GlId createBeamProgram()
{
    using namespace juce::gl;

    const GlId vertexShader = compileShader(GL_VERTEX_SHADER, kBeamVertex);
    const GlId fragmentShader = compileShader(GL_FRAGMENT_SHADER, kBeamFragment);
    const GlId program = glCreateProgram();

    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glBindAttribLocation(program, 0, "segmentStart");
    glBindAttribLocation(program, 1, "segmentEnd");
    glBindAttribLocation(program, 2, "cornerIndex");
    glLinkProgram(program);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    int success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (success == GL_FALSE)
    {
        char log[1024] = {};
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        glDeleteProgram(program);
        throw std::runtime_error(std::string("OpenGL shader link failed: ") + log);
    }

    return program;
}

GlId createDotImageProgram()
{
    using namespace juce::gl;

    const GlId vertexShader = compileShader(GL_VERTEX_SHADER, kDotImageVertex);
    const GlId fragmentShader = compileShader(GL_FRAGMENT_SHADER, kDotImageFragment);
    const GlId program = glCreateProgram();

    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glBindAttribLocation(program, 0, "dotPosition");
    glLinkProgram(program);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    int success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (success == GL_FALSE)
    {
        char log[1024] = {};
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        glDeleteProgram(program);
        throw std::runtime_error(std::string("OpenGL shader link failed: ") + log);
    }

    return program;
}

class ScreenQuad
{
  public:
    void initialise()
    {
        using namespace juce::gl;

        constexpr float screenVertices[] = {-1.0f, -1.0f, 0.0f, 0.0f, 1.0f, -1.0f,
                                            1.0f,  0.0f,  -1.0f, 1.0f, 0.0f, 1.0f,
                                            -1.0f, 1.0f,  0.0f,  1.0f, 1.0f, -1.0f,
                                            1.0f,  0.0f,  1.0f,  1.0f, 1.0f, 1.0f};

        glGenVertexArrays(1, &vertexArray);
        glBindVertexArray(vertexArray);

        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(screenVertices), screenVertices, GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4, nullptr);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4,
                              reinterpret_cast<void *>(sizeof(float) * 2));

        glBindVertexArray(0);
    }

    void draw() const
    {
        using namespace juce::gl;

        glBindVertexArray(vertexArray);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glBindVertexArray(0);
    }

    void destroy()
    {
        using namespace juce::gl;

        if (vertexBuffer != 0)
        {
            glDeleteBuffers(1, &vertexBuffer);
            vertexBuffer = 0;
        }

        if (vertexArray != 0)
        {
            glDeleteVertexArrays(1, &vertexArray);
            vertexArray = 0;
        }
    }

  private:
    GlId vertexArray{};
    GlId vertexBuffer{};
};

class BeamRenderer
{
  public:
    void initialise()
    {
        using namespace juce::gl;

        program = createBeamProgram();

        glGenVertexArrays(1, &vertexArray);
        glBindVertexArray(vertexArray);

        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(BeamVertex),
                              reinterpret_cast<void *>(offsetof(BeamVertex, startX)));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(BeamVertex),
                              reinterpret_cast<void *>(offsetof(BeamVertex, endX)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, sizeof(BeamVertex),
                              reinterpret_cast<void *>(offsetof(BeamVertex, corner)));

        glBindVertexArray(0);
    }

    int uploadSegments(const SignalBuffer &signal, const PhosphorParams &params, int width,
                       int height)
    {
        using namespace juce::gl;

        vertices.clear();
        if (!signal.renderable())
        {
            return 0;
        }

        vertices.reserve((signal.size() - 1) * 6);
        constexpr float corners[6] = {0.0f, 1.0f, 2.0f, 2.0f, 1.0f, 3.0f};
        for (size_t i = 1; i < signal.size(); ++i)
        {
            const auto a = mapSample(signal, i - 1, params, width, height);
            const auto b = mapSample(signal, i, params, width, height);

            for (const auto corner : corners)
            {
                vertices.push_back({a.x, a.y, b.x, b.y, corner});
            }
        }

        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, static_cast<ptrdiff_t>(vertices.size() * sizeof(BeamVertex)),
                     vertices.data(), GL_DYNAMIC_DRAW);
        return static_cast<int>(vertices.size());
    }

    void draw(int vertexCount, RgbColor color, float width, float intensity, int viewportWidth,
              int viewportHeight) const
    {
        using namespace juce::gl;

        if (vertexCount <= 0)
        {
            return;
        }

        glUseProgram(program);
        glUniform3f(glGetUniformLocation(program, "beamColor"), color.r, color.g, color.b);
        glUniform1f(glGetUniformLocation(program, "beamSize"), width);
        glUniform1f(glGetUniformLocation(program, "beamIntensity"), intensity);
        glUniform2f(glGetUniformLocation(program, "viewportSize"),
                    static_cast<float>(viewportWidth), static_cast<float>(viewportHeight));
        glBindVertexArray(vertexArray);
        glDrawArrays(GL_TRIANGLES, 0, vertexCount);
        glBindVertexArray(0);
        glUseProgram(0);
    }

    void destroy()
    {
        using namespace juce::gl;

        if (vertexBuffer != 0)
        {
            glDeleteBuffers(1, &vertexBuffer);
            vertexBuffer = 0;
        }
        if (vertexArray != 0)
        {
            glDeleteVertexArrays(1, &vertexArray);
            vertexArray = 0;
        }
        if (program != 0)
        {
            glDeleteProgram(program);
            program = 0;
        }
        vertices.clear();
    }

  private:
    static Point mapSample(const SignalBuffer &signal, size_t index, const PhosphorParams &params,
                           int width, int height)
    {
        const auto aspect = width > height ? static_cast<float>(height) / static_cast<float>(width)
                                           : 1.0f;
        const auto verticalAspect =
            height > width ? static_cast<float>(width) / static_cast<float>(height) : 1.0f;
        return {signal.l(index) * params.traceGain * 0.82f * aspect,
                signal.r(index) * params.traceGain * 0.82f * verticalAspect};
    }

    GlId program{};
    GlId vertexArray{};
    GlId vertexBuffer{};
    std::vector<BeamVertex> vertices;
};

class DotImageRenderer
{
  public:
    void initialise()
    {
        using namespace juce::gl;

        program = createDotImageProgram();

        glGenVertexArrays(1, &vertexArray);
        glBindVertexArray(vertexArray);

        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(DotPointVertex), nullptr);

        glBindVertexArray(0);
    }

    int uploadPoints(const SignalBuffer &signal, const PhosphorParams &params, int width,
                     int height)
    {
        using namespace juce::gl;

        points.clear();
        if (!signal.renderable())
        {
            return 0;
        }

        points.reserve(signal.size());
        for (size_t i = 0; i < signal.size(); ++i)
        {
            const auto p = mapSample(signal, i, params, width, height);
            points.push_back({p.x, p.y});
        }

        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER,
                     static_cast<ptrdiff_t>(points.size() * sizeof(DotPointVertex)),
                     points.data(), GL_DYNAMIC_DRAW);
        return static_cast<int>(points.size());
    }

    void updateTextures(const ScopeDotImages &dotImages)
    {
        for (size_t i = 0; i < textures.size(); ++i)
        {
            if (revisions[i] == dotImages.slots[i].revision)
            {
                continue;
            }

            revisions[i] = dotImages.slots[i].revision;
            uploadTexture(i, dotImages.slots[i].image);
        }
    }

    void draw(size_t dotIndex, int pointCount, float pointSize, float intensity, float imageMix,
              int viewportWidth, int viewportHeight) const
    {
        using namespace juce::gl;

        if (dotIndex >= textures.size() || textures[dotIndex] == 0 || pointCount <= 0 ||
            imageMix <= 0.0f || intensity <= 0.0f)
        {
            return;
        }

        glEnable(0x8642); // GL_PROGRAM_POINT_SIZE
        glUseProgram(program);
        glUniform2f(glGetUniformLocation(program, "viewportSize"),
                    static_cast<float>(viewportWidth), static_cast<float>(viewportHeight));
        glUniform1f(glGetUniformLocation(program, "pointSize"), pointSize);
        glUniform1f(glGetUniformLocation(program, "intensity"), intensity);
        glUniform1f(glGetUniformLocation(program, "imageMix"), imageMix);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textures[dotIndex]);
        glUniform1i(glGetUniformLocation(program, "dotTexture"), 0);
        glBindVertexArray(vertexArray);
        glDrawArrays(GL_POINTS, 0, pointCount);
        glBindVertexArray(0);
        glUseProgram(0);
    }

    void destroy()
    {
        using namespace juce::gl;

        for (auto &texture : textures)
        {
            if (texture != 0)
            {
                glDeleteTextures(1, &texture);
                texture = 0;
            }
        }
        if (vertexBuffer != 0)
        {
            glDeleteBuffers(1, &vertexBuffer);
            vertexBuffer = 0;
        }
        if (vertexArray != 0)
        {
            glDeleteVertexArrays(1, &vertexArray);
            vertexArray = 0;
        }
        if (program != 0)
        {
            glDeleteProgram(program);
            program = 0;
        }
        points.clear();
        revisions = {};
    }

  private:
    static Point mapSample(const SignalBuffer &signal, size_t index, const PhosphorParams &params,
                           int width, int height)
    {
        const auto aspect = width > height ? static_cast<float>(height) / static_cast<float>(width)
                                           : 1.0f;
        const auto verticalAspect =
            height > width ? static_cast<float>(width) / static_cast<float>(height) : 1.0f;
        return {signal.l(index) * params.traceGain * 0.82f * aspect,
                signal.r(index) * params.traceGain * 0.82f * verticalAspect};
    }

    void uploadTexture(size_t dotIndex, const juce::Image &image)
    {
        using namespace juce::gl;

        if (dotIndex >= textures.size())
        {
            return;
        }

        if (textures[dotIndex] != 0)
        {
            glDeleteTextures(1, &textures[dotIndex]);
            textures[dotIndex] = 0;
        }

        if (!image.isValid())
        {
            return;
        }

        const auto converted = image.convertedToFormat(juce::Image::ARGB);
        const auto width = converted.getWidth();
        const auto height = converted.getHeight();
        if (width <= 0 || height <= 0)
        {
            return;
        }

        std::vector<unsigned char> pixels(static_cast<size_t>(width * height * 4));
        for (int y = 0; y < height; ++y)
        {
            for (int x = 0; x < width; ++x)
            {
                const auto c = converted.getPixelAt(x, y);
                const auto offset = static_cast<size_t>((y * width + x) * 4);
                pixels[offset + 0] = c.getRed();
                pixels[offset + 1] = c.getGreen();
                pixels[offset + 2] = c.getBlue();
                pixels[offset + 3] = c.getAlpha();
            }
        }

        glGenTextures(1, &textures[dotIndex]);
        glBindTexture(GL_TEXTURE_2D, textures[dotIndex]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE,
                     pixels.data());
    }

    GlId program{};
    GlId vertexArray{};
    GlId vertexBuffer{};
    std::array<GlId, 2> textures{};
    std::array<uint64_t, 2> revisions{};
    std::vector<DotPointVertex> points;
};

class PersistenceBuffer
{
  public:
    void initialise()
    {
        textureProgram = createProgram(kScreenVertex, kTextureFragment);
        decayProgram = createProgram(kScreenVertex, kDecayFragment);
    }

    void beginFrame(const PhosphorParams &params, int width, int height, const ScreenQuad &quad)
    {
        using namespace juce::gl;

        ensureTargets(width, height, params);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ZERO);

        const auto read = 1 - activeTarget;
        const auto write = activeTarget;

        glBindFramebuffer(GL_FRAMEBUFFER, targets[write].framebuffer);
        glViewport(0, 0, width, height);
        glUseProgram(decayProgram);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, targets[read].texture);
        glUniform1i(glGetUniformLocation(decayProgram, "image"), 0);
        glUniform3f(glGetUniformLocation(decayProgram, "backgroundColor"), params.backgroundColor.r,
                    params.backgroundColor.g, params.backgroundColor.b);
        glUniform1f(glGetUniformLocation(decayProgram, "persistence"), params.persistence);
        glUniform1f(glGetUniformLocation(decayProgram, "fastDecay"), params.fastDecay);
        glUniform1f(glGetUniformLocation(decayProgram, "afterglow"), params.afterglow);
        glUniform1f(glGetUniformLocation(decayProgram, "floorFade"), params.floorFade);
        quad.draw();

        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    }

    void endFrame(const ScreenQuad &quad, int width, int height)
    {
        using namespace juce::gl;

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, width, height);
        glBlendFunc(GL_ONE, GL_ZERO);
        glUseProgram(textureProgram);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, targets[activeTarget].texture);
        glUniform1i(glGetUniformLocation(textureProgram, "image"), 0);
        quad.draw();
        glUseProgram(0);
        activeTarget = 1 - activeTarget;
    }

    void destroy()
    {
        using namespace juce::gl;

        for (auto &target : targets)
        {
            if (target.texture != 0)
            {
                glDeleteTextures(1, &target.texture);
                target.texture = 0;
            }
            if (target.framebuffer != 0)
            {
                glDeleteFramebuffers(1, &target.framebuffer);
                target.framebuffer = 0;
            }
        }
        if (textureProgram != 0)
        {
            glDeleteProgram(textureProgram);
            textureProgram = 0;
        }
        if (decayProgram != 0)
        {
            glDeleteProgram(decayProgram);
            decayProgram = 0;
        }
        targetWidth = 0;
        targetHeight = 0;
        lastClearRevision = -1;
    }

  private:
    struct Target
    {
        GlId framebuffer{};
        GlId texture{};
    };

    void ensureTargets(int width, int height, const PhosphorParams &params)
    {
        using namespace juce::gl;

        const auto needsResize = width != targetWidth || height != targetHeight;
        const auto needsClear = needsResize || lastClearRevision != params.clearRevision;
        if (needsResize)
        {
            for (auto &target : targets)
            {
                if (target.texture != 0)
                {
                    glDeleteTextures(1, &target.texture);
                    target.texture = 0;
                }
                if (target.framebuffer != 0)
                {
                    glDeleteFramebuffers(1, &target.framebuffer);
                    target.framebuffer = 0;
                }

                glGenTextures(1, &target.texture);
                glBindTexture(GL_TEXTURE_2D, target.texture);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA,
                             GL_UNSIGNED_BYTE, nullptr);

                glGenFramebuffers(1, &target.framebuffer);
                glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer);
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                                       target.texture, 0);
            }
            targetWidth = width;
            targetHeight = height;
        }

        if (needsClear)
        {
            for (const auto &target : targets)
            {
                glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer);
                glViewport(0, 0, width, height);
                glClearColor(params.backgroundColor.r, params.backgroundColor.g,
                             params.backgroundColor.b, 1.0f);
                glClear(GL_COLOR_BUFFER_BIT);
            }
            activeTarget = 0;
            lastClearRevision = params.clearRevision;
        }
    }

    std::array<Target, 2> targets{};
    GlId textureProgram{};
    GlId decayProgram{};
    int targetWidth{};
    int targetHeight{};
    int activeTarget{};
    int lastClearRevision{-1};
};
} // namespace

struct PhosphorScopeRenderer::Impl
{
    ScreenQuad quad;
    BeamRenderer beam;
    DotImageRenderer dotImages;
    PersistenceBuffer persistence;
    SignalBuffer signal;
    bool initialised{false};

    void initialise()
    {
        quad.initialise();
        beam.initialise();
        dotImages.initialise();
        persistence.initialise();
        initialised = true;
    }

    void shutdown()
    {
        persistence.destroy();
        dotImages.destroy();
        beam.destroy();
        quad.destroy();
        signal.left.clear();
        signal.right.clear();
        signal.lastSnapshotSerial = std::numeric_limits<uint64_t>::max();
        signal.lastTimeScale = 0.0f;
        initialised = false;
    }

    void render(const ScopeRenderContext &context, const ScopeAudioSnapshot &snapshot,
                const ScopeVisualState &visualState, const ScopeDotImages &dotImageState)
    {
        using namespace juce::gl;

        if (!context.hasDrawableArea() || !initialised)
        {
            juce::OpenGLHelpers::clear(juce::Colour(0xff05030a));
            return;
        }

        const auto width = context.pixelWidth();
        const auto height = context.pixelHeight();

        PhosphorParams params;
        const auto persistenceRatio = visualState.screenBurnPersistence / 0.98f;
        const auto fastDecayRatio = visualState.screenBurnFastDecay / 0.25f;
        const auto afterglowRatio = visualState.screenBurnAfterglow / 0.95f;
        const auto dot1HaloRatio =
            (visualState.dot1Halo / 0.35f) * visualState.dotOverallHalo;
        const auto dot2HaloRatio =
            (visualState.dot2Halo / 0.65f) * visualState.dotOverallHalo;
        const auto dot1ImageMix =
            dotImageState.slots[0].hasImage()
                ? std::clamp(visualState.dot1ImageMix * visualState.dotOverallImageMix, 0.0f,
                             1.0f)
                : 0.0f;
        const auto dot2ImageMix =
            dotImageState.slots[1].hasImage()
                ? std::clamp(visualState.dot2ImageMix * visualState.dotOverallImageMix, 0.0f,
                             1.0f)
                : 0.0f;

        params.persistence =
            std::clamp(visualState.phosphorDecay * persistenceRatio, 0.0f, 0.9995f);
        params.traceGain = std::clamp(0.10f * visualState.inputGain, 0.002f, 1.2f);
        params.coreWidth = std::clamp(visualState.beamTraceWidth * visualState.dot1Size *
                                          visualState.dotOverallSize / 2.0f *
                                          (0.65f + 0.35f * dot1HaloRatio),
                                      0.15f, 96.0f);
        params.glowWidth = std::clamp(visualState.beamGlowWidth * visualState.dot2Size *
                                          visualState.dotOverallSize / 6.0f,
                                      0.25f, 160.0f);
        params.coreIntensity = std::clamp(1.15f * visualState.beamIntensity / 1.6f *
                                              visualState.dot1Intensity *
                                              visualState.dotOverallIntensity *
                                              (1.0f - dot1ImageMix),
                                          0.0f, 12.0f);
        params.glowIntensity =
            std::clamp(visualState.beamGlowStrength * visualState.beamIntensity / 1.6f *
                           (visualState.dot2Intensity / 0.45f) *
                           visualState.dotOverallIntensity * dot2HaloRatio *
                           (1.0f - dot2ImageMix),
                       0.0f, 12.0f);
        params.fastDecay =
            std::clamp(visualState.phosphorFastDecay * fastDecayRatio, 0.0f, 1.0f);
        params.afterglow =
            std::clamp(visualState.phosphorAfterglow * afterglowRatio, 0.0f, 1.0f);
        params.floorFade = visualState.screenBurnFloorFade;

        signal.append(snapshot, visualState.timeScale, snapshot.serial);
        const auto vertexCount = beam.uploadSegments(signal, params, width, height);
        const auto pointCount = dotImages.uploadPoints(signal, params, width, height);
        dotImages.updateTextures(dotImageState);

        persistence.beginFrame(params, width, height, quad);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        beam.draw(vertexCount, params.glowColor, params.glowWidth, params.glowIntensity, width,
                  height);
        beam.draw(vertexCount, params.traceColor, params.coreWidth, params.coreIntensity, width,
                  height);
        dotImages.draw(1, pointCount, params.glowWidth, visualState.dot2Intensity *
                                                        visualState.dotOverallIntensity,
                       dot2ImageMix, width, height);
        dotImages.draw(0, pointCount, params.coreWidth, visualState.dot1Intensity *
                                                        visualState.dotOverallIntensity,
                       dot1ImageMix, width, height);
        persistence.endFrame(quad, width, height);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
};

PhosphorScopeRenderer::PhosphorScopeRenderer() : impl(std::make_unique<Impl>()) {}

PhosphorScopeRenderer::~PhosphorScopeRenderer() = default;

void PhosphorScopeRenderer::initialise(juce::OpenGLContext &)
{
    impl->initialise();
}

void PhosphorScopeRenderer::render(const ScopeRenderContext &context,
                                   const ScopeAudioSnapshot &snapshot,
                                   const ScopeVisualState &visualState,
                                   const ScopeDotImages &dotImages)
{
    impl->render(context, snapshot, visualState, dotImages);
}

void PhosphorScopeRenderer::shutdown()
{
    impl->shutdown();
}
} // namespace baconpaul::sidequest_ns::ui
