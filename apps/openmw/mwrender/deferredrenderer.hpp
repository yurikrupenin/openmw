#ifndef OPENMW_MWRENDER_DEFERREDRENDERER_H
#define OPENMW_MWRENDER_DEFERREDRENDERER_H

#include <osg/Camera>
#include <osg/Group>
#include <osg/MatrixTransform>
#include <osg/Texture2D>
#include <osg/TextureRectangle>
#include <osgShadow/ShadowedScene>


namespace MWRender
{


struct DeferredPipeline
{
    int textureSize;
    osg::Group *graph;
    osg::Texture *pass2Colors;
    osg::Texture *pass2Normals;
    osg::Texture *pass2Positions;
    osg::Texture *pass3Final;
};

osg::TextureRectangle *createFloatTextureRectangle(int textureSize);

osg::Camera *createHUDCamera(double left = 0,
    double right = 1,
    double bottom = 0,
    double top = 1);

osg::ref_ptr<osg::LightSource> createLight(const osg::Vec3 &pos);

DeferredPipeline createDeferredPipeline(osg::ref_ptr<osg::Group> scene);

osg::Camera *createRTTCamera(osg::Camera::BufferComponent buffer,
    osg::Texture *tex,
    bool isAbsolute = false);

osg::ref_ptr<osg::Group> createSceneRoom();

osg::Geode *createScreenQuad(float width,
    float height,
    float scale = 1,
    osg::Vec3 corner = osg::Vec3());

osg::Texture2D *createTexture(const std::string &fileName);

osg::ref_ptr<osg::Camera> createTextureDisplayQuad(const osg::Vec3 &pos,
    osg::StateAttribute *tex,
    float scale,
    float width = 0.3,
    float height = 0.2);

void setAnimationPath(osg::ref_ptr<osg::MatrixTransform> node,
    const osg::Vec3 &center,
    float time,
    float radius);

osg::ref_ptr<osg::StateSet> setShaderProgram(osg::ref_ptr<osg::Camera> pass,
    const std::string& vert,
    const std::string& frag);


} /* namespace MWRender */

#endif /* OPENMW_MWRENDER_DEFERREDRENDERER_H */