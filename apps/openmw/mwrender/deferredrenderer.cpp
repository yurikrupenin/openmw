#include "deferredrenderer.hpp"

#include <osg/PolygonMode>
#include <osg/TextureRectangle>
#include <osgViewer/Viewer>
#include <osgViewer/ViewerEventHandlers>


namespace MWRender
{

    typedef enum {
        GBUF_DIFFUSE,
        GBUF_NORMAL,
        GBUF_ROUGHNESS,
        GBUF_SPECULAR,
        GBUF_POS,
        GBUF_STENCIL,
        GBUF_FINAL,
        GBUF_MAX
    } GBufferLayout;

    osg::TextureRectangle* gbuffer[GBUF_MAX] = { 0,0,0,0,0,0,0 };

static std::string vertex_shader =
{
        "#version 330\n"
        "layout(location = 0) in vec4 osg_Vertex;        \n"
        "layout(location = 1) in vec3 osg_Normal;        \n"
        "layout(location = 2) in vec4 osg_Color;        \n"
        "layout(location = 3) in vec4 osg_MultiTexCoord0; \n"
        "uniform mat4 osg_ModelViewProjectionMatrix; \n"
        "out vec2 texCoords;"
        "void main(void) \n"
        "{ \n"
                "texCoords = osg_MultiTexCoord0.st;\n"
        "        gl_Position = osg_ModelViewProjectionMatrix * osg_Vertex; \n"
        "}\n"
};

static std::string def_frag_shader =
{
        "#version 330\n"
        "uniform sampler2DRect textureID0;\n"

        "in vec2 texCoords;"
        "out vec4 target;"
        "void main(void)\n"
        "{\n"
        "    target = vec4(texture( textureID0, texCoords.st ).rgb, 1);  \n"
        "}\n"
};

static const char* combineShaderSource = {
                               "#version 330\n"

                               "const float gamma = 2.2;\n"
                               "const float roughnessMultiplier = 1.0;\n"
                               "const float glossMultiplier = 1.0;\n"
                               "const float ambientLight = 4.13;\n"

                               "uniform sampler2DRect diffuseMap;\n"
                               "uniform sampler2DRect normalMap;\n"
                               "uniform sampler2DRect specularMap;\n"
                               "uniform sampler2DRect roughnessMap;\n"

                               "in vec2 texCoords;\n"
                               "out vec4 fragColor;\n"

                               

                               "void main(void)\n"
                               "{\n"
                                "float roughness = texture2DRect(roughnessMap, texCoords).r * roughnessMultiplier;\n"

                                "//TODO: Adjust roughness!\n"

                                "vec3 specular = pow(texture2DRect(specularMap, texCoords).rgb, vec3(gamma)) * glossMultiplier;\n"

                                "vec4 diffuse = texture2DRect(diffuseMap, texCoords).rgba;\n"
                                "vec3 albedo = pow(diffuse.rgb, vec3(gamma));\n"

                                "vec3 Lo = vec3(0.0);\n"

                                "//TODO: Per-light computation\n"

                                "// Ambient lighting colculation\n"
                                "// HACK: grab it from cell's ambient lighting\n"
                                "vec3 ambient = vec3(ambientLight) * albedo;\n"
                                
                                "vec3 color = ambient + Lo;\n"
                                "//HDR tonemapping\n"
                                "color = color / (color + vec3(1.0));\n"

                                "// gamma correct\n"
                                "color = pow(color, vec3(1.0/gamma));\n"
            
                                "clamp(color, 0.0, 1.0);\n"

                                "fragColor = vec4(color, diffuse.a);\n"
                         
                                "}\n"
};


osg::Camera *createHUDCamera(double left,
    double right,
    double bottom,
    double top)
{
    osg::ref_ptr<osg::Camera> camera = new osg::Camera;
    camera->setReferenceFrame(osg::Transform::ABSOLUTE_RF);
    camera->setClearMask(GL_DEPTH_BUFFER_BIT);
    camera->setRenderOrder(osg::Camera::POST_RENDER);
    camera->setAllowEventFocus(false);
    camera->setProjectionMatrix(osg::Matrix::ortho2D(left, right, bottom, top));
    camera->getOrCreateStateSet()->setMode(GL_LIGHTING, osg::StateAttribute::OFF);
    return camera.release();
}

osg::ref_ptr<osg::LightSource> createLight(const osg::Vec3 &pos)
{
    osg::ref_ptr<osg::LightSource> light = new osg::LightSource;
    light->getLight()->setPosition(osg::Vec4(pos.x(), pos.y(), pos.z(), 1));
    light->getLight()->setAmbient(osg::Vec4(0.2, 0.2, 0.2, 1));
    light->getLight()->setDiffuse(osg::Vec4(0.8, 0.8, 0.8, 1));
    return light;
}


DeferredPipeline createDeferredPipeline(osg::ref_ptr<osg::Group> scene)
{

    //Shader::ShaderManager& shaderMgr = mResourceSystem->getSceneManager()->getShaderManager();
    //osg::ref_ptr<osg::Shader> fragmentShader(shaderMgr.getShader("s360_fragment.glsl", defineMap, osg::Shader::FRAGMENT));
    //osg::ref_ptr<osg::Shader> vertexShader(shaderMgr.getShader("s360_vertex.glsl", defineMap, osg::Shader::VERTEX));
    //osg::ref_ptr<osg::StateSet> stateset = new osg::StateSet;

    DeferredPipeline p;
    p.graph = new osg::Group();
    p.textureWidth = 1920;
    p.textureHeight = 1080;

    for (int pos = 0; pos < GBUF_MAX; pos++)
    {
        gbuffer[pos] = new osg::TextureRectangle;
        gbuffer[pos]->setTextureSize(p.textureWidth, p.textureHeight);
        gbuffer[pos]->setInternalFormat(GL_RGBA);
        gbuffer[pos]->setFilter(osg::Texture2D::MIN_FILTER, osg::Texture2D::LINEAR);
        gbuffer[pos]->setFilter(osg::Texture2D::MAG_FILTER, osg::Texture2D::LINEAR);

        gbuffer[pos]->setDataVariance(osg::Object::DYNAMIC);
        gbuffer[pos]->setInternalFormat(GL_RGBA16F_ARB);
        gbuffer[pos]->setSourceFormat(GL_RGBA);
        gbuffer[pos]->setSourceType(GL_FLOAT);
    }

    osg::ref_ptr<osg::Camera> gbufGenerator =
        createRTTCamera(osg::Camera::COLOR_BUFFER, gbuffer[GBUF_DIFFUSE]);

    gbufGenerator->attach(osg::Camera::COLOR_BUFFER0, gbuffer[GBUF_DIFFUSE], 0, 1);
    gbufGenerator->attach(osg::Camera::COLOR_BUFFER1, gbuffer[GBUF_NORMAL], 0, 1);
    gbufGenerator->attach(osg::Camera::COLOR_BUFFER2, gbuffer[GBUF_ROUGHNESS], 0, 1);
    gbufGenerator->attach(osg::Camera::COLOR_BUFFER3, gbuffer[GBUF_SPECULAR], 0, 1);
    gbufGenerator->attach(osg::Camera::COLOR_BUFFER4, gbuffer[GBUF_POS], 0, 1);
    gbufGenerator->attach(osg::Camera::COLOR_BUFFER5, gbuffer[GBUF_STENCIL], 0, 1);
    gbufGenerator->addChild(scene.get());
    
    osg::ref_ptr<osg::Camera> finalCombine =
        createRTTCamera(osg::Camera::COLOR_BUFFER, gbuffer[GBUF_FINAL], true);

    // Graph.
    p.graph->addChild(gbufGenerator);
    p.graph->addChild(finalCombine);

    // Quads to display debug maps.
    osg::ref_ptr<osg::Camera> normalQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0, 0.7, 0),
            gbuffer[GBUF_NORMAL],
            p.textureWidth,
            p.textureHeight);
    osg::ref_ptr<osg::Camera> roughnessQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0, 0.35, 0),
            gbuffer[GBUF_ROUGHNESS],
            p.textureWidth,
            p.textureHeight);
    osg::ref_ptr<osg::Camera> specularQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0, 0, 0),
            gbuffer[GBUF_SPECULAR],
            p.textureWidth,
            p.textureHeight);

    osg::ref_ptr<osg::Camera> diffuseQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0.7, 0.7, 0),
            gbuffer[GBUF_DIFFUSE],
            p.textureWidth,
            p.textureHeight);
    osg::ref_ptr<osg::Camera> posQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0.7, 0.35, 0),
            gbuffer[GBUF_POS],
            p.textureWidth,
            p.textureHeight);
    osg::ref_ptr<osg::Camera> stencilQuad =
        createTextureDisplayQuad(
            false,
            osg::Vec3(0.7, 0, 0),
            gbuffer[GBUF_STENCIL],
            p.textureWidth,
            p.textureHeight);

    // Final image
    osg::ref_ptr<osg::Camera> finalTarget =
        createTextureDisplayQuad(
            true,
            osg::Vec3(0, 0, 0),
            gbuffer[GBUF_FINAL],
            p.textureWidth,
            p.textureHeight,
            1,
            1);

    p.graph->addChild(finalTarget.get());
    p.graph->addChild(normalQuad.get());
    p.graph->addChild(roughnessQuad.get());
    p.graph->addChild(specularQuad.get());
    p.graph->addChild(diffuseQuad.get());
    p.graph->addChild(posQuad.get());
    p.graph->addChild(stencilQuad.get());

    return p;
}

osg::Camera *createRTTCamera(osg::Camera::BufferComponent buffer,
    osg::Texture *tex,
    bool isAbsolute)
{
    osg::ref_ptr<osg::Camera> camera = new osg::Camera;
    camera->setClearColor(osg::Vec4());
    camera->setClearMask(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    camera->setRenderTargetImplementation(osg::Camera::FRAME_BUFFER_OBJECT);
    camera->setRenderOrder(osg::Camera::PRE_RENDER);
    if (tex)
    {
        tex->setFilter(osg::Texture2D::MIN_FILTER, osg::Texture2D::LINEAR);
        tex->setFilter(osg::Texture2D::MAG_FILTER, osg::Texture2D::LINEAR);
        camera->setViewport(0, 0, tex->getTextureWidth(), tex->getTextureHeight());
        camera->attach(buffer, tex);
    }
    if (isAbsolute)
    {
        camera->setReferenceFrame(osg::Transform::ABSOLUTE_RF);
        camera->setProjectionMatrix(osg::Matrix::ortho2D(0.0, 1.0, 0.0, 1.0));
        camera->setViewMatrix(osg::Matrix::identity());
        camera->addChild(createScreenQuad(1.0f, 1.0));
    }
    return camera.release();
}

osg::Geode *createScreenQuad(float width,
    float height,
    float scaleX,
    float scaleY,
    osg::Vec3 corner)
{
    osg::Geometry* geom = osg::createTexturedQuadGeometry(
        corner,
        osg::Vec3(width, 0, 0),
        osg::Vec3(0, height, 0),
        0,
        0,
        scaleX,
        scaleY);
    osg::ref_ptr<osg::Geode> quad = new osg::Geode;
    quad->addDrawable(geom);
    int values = osg::StateAttribute::OFF | osg::StateAttribute::PROTECTED;
    quad->getOrCreateStateSet()->setAttribute(
        new osg::PolygonMode(osg::PolygonMode::FRONT_AND_BACK,
            osg::PolygonMode::FILL),
        values);
    quad->getOrCreateStateSet()->setMode(GL_LIGHTING, values);
    return quad.release();
}

osg::ref_ptr<osg::Camera> createTextureDisplayQuad(
    const bool final,
    const osg::Vec3 &pos,
    osg::StateAttribute *tex,
    float scaleX,
    float scaleY,
    float width,
    float height)
{
    osg::ref_ptr<osg::Camera> hc = createHUDCamera();
    osg::Geode* polyGeom = createScreenQuad(width, height, scaleX, scaleY, pos);
    hc->addChild(polyGeom); 

    osg::ref_ptr<osg::Program> program = new osg::Program;

    if (!final)
    {
        hc->getOrCreateStateSet()->setTextureAttributeAndModes(0, tex);

        osg::ref_ptr<osg::Shader> vshader = new
            osg::Shader(osg::Shader::VERTEX, vertex_shader);
        osg::ref_ptr<osg::Shader> fshader = new
            osg::Shader(osg::Shader::FRAGMENT, def_frag_shader);
        program->addShader(vshader.get());
        program->addShader(fshader.get());

        hc->getOrCreateStateSet()->setAttributeAndModes(program.get(),
            osg::StateAttribute::ON | osg::StateAttribute::OVERRIDE);
    }
    else
    {
        osg::ref_ptr<osg::Shader> vshader = new
            osg::Shader(osg::Shader::VERTEX, vertex_shader);
        osg::ref_ptr<osg::Shader> fshader = new
            osg::Shader(osg::Shader::FRAGMENT, combineShaderSource);
        program->addShader(vshader.get());
        program->addShader(fshader.get());

        osg::StateSet* stateset = new osg::StateSet;

        for (int current = 0; current < GBUF_MAX; current++) {
            stateset->setTextureAttributeAndModes(current, gbuffer[current],
                osg::StateAttribute::ON);
        }

        polyGeom->setStateSet(stateset);
        
        stateset->setAttributeAndModes(program.get(),
            osg::StateAttribute::ON | osg::StateAttribute::OVERRIDE);

        stateset->addUniform(new osg::Uniform("diffuseMap", GBUF_DIFFUSE));
        stateset->addUniform(new osg::Uniform("normalMap", GBUF_NORMAL));
        stateset->addUniform(new osg::Uniform("roughnessMap", GBUF_ROUGHNESS));
        stateset->addUniform(new osg::Uniform("specularMap", GBUF_SPECULAR));
        stateset->addUniform(new osg::Uniform("posMap", GBUF_POS));
        stateset->addUniform(new osg::Uniform("stencilMap", GBUF_STENCIL));
    }

    return hc;
}


} /* namespace MWRender */
