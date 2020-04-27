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
};

osg::Camera *createHUDCamera(double left = 0,
    double right = 1,
    double bottom = 0,
    double top = 1);

DeferredPipeline createDeferredPipeline(osg::ref_ptr<osg::Group> scene);

osg::Camera *createRTTCamera(osg::Camera::BufferComponent buffer,
    osg::Texture *tex,
    bool isAbsolute = false);

osg::Geode *createScreenQuad(float width,
    float height,
    float scale = 1,
    osg::Vec3 corner = osg::Vec3());

osg::ref_ptr<osg::Camera> createTextureDisplayQuad(const bool final,
    const osg::Vec3 &pos,
    osg::StateAttribute *tex,
    float scale,
    float width = 0.3,
    float height = 0.24);


} /* namespace MWRender */

#endif /* OPENMW_MWRENDER_DEFERREDRENDERER_H */
