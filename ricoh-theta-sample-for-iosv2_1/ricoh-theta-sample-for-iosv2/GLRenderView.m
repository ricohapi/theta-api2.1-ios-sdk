/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKit.h>
#import "GLRenderView.h"
#import "UVSphere.h"
#import "ImageViewController.h"
#import "Constants.h"


NSString *vertexShader = @""
    "attribute vec4 aPosition;\n"
    "attribute vec2 aUV;\n"
    "uniform mat4 uProjection;\n"
    "uniform mat4 uView;\n"
    "uniform mat4 uModel;\n"
    "varying vec2 vUV;\n"
    "void main() {\n"
    "  gl_Position = uProjection * uView * uModel * aPosition;\n"
    "  vUV = aUV;\n"
    "}\n";
NSString *fragmentShader = @""
    "precision mediump float;\n"
    "varying vec2 vUV;\n"
    "uniform sampler2D uTex;\n"
    "void main() {\n"
    "  gl_FragColor = texture2D(uTex, vUV);\n"
    "}\n";


/**
 * View class for photo spherical display
 *
 * Images acquired from RICOH THETA S are created by equirectangular projection,
 * with the images from camera #2 (left half) + camera #1 +camera#2 (right half) joined at the ends. 
 * These images can be acquired at a resolution of up to 5376 x 2688.
 *
 * These images are pasted as texture onto a spherical object on OpenGL using UVSphere
 * from this class.  As this sphere is drawn at an angle from -pi to pi on the xz plane,
 * the UV coordinates are generated in this orientation and attached to the image,
 * and are attached so that a mirror image is not generated in the x axis direction
 * when viewed from the inside of the sphere.
 *
 * Furthermore, as the camera image is from angle -pi, the center of the image captured by
 * camera #1 faces forward from the x axis. The camera image is slanted at the angle of elevation
 * and horizontal angle, the sphere is rotated at each angle, and the image displayed in the x axis
 * forward direction is adjusted to the horizontal direction of the image from camera#1.
 *
 * Pinch and pan operations support zooming in, zooming out and rotating. These are supported by
 * changing the camera slant and FOV angle setting value.
 */
@interface GLRenderView (){
    UVSphere *half[2];

    UIPanGestureRecognizer *panGestureRecognizer;
    UIPinchGestureRecognizer *pinchGestureRecognizer;

    float _yaw;
    float _roll;
    float _pitch;
    NSTimer *_timer;
    uint _timerCount;
    int _kindInertia;
    float viewAspectRatio;

    GLKMatrix4 projectionMatrix;
    GLKMatrix4 lookAtMatrix;
    GLKMatrix4 modelMatrix;

    GLuint shaderProgram;
    GLint aPosition;
    GLint aUV;

    GLint uProjection;
    GLint uView;
    GLint uModel;
    GLint uTex;

    NSDictionary *_textureInfo;

    float cameraPosX;
    float cameraPosY;
    float cameraPosZ;
    float cameraDirectionX;
    float cameraDirectionY;
    float cameraDirectionZ;
    float cameraUpX;
    float cameraUpY;
    float cameraUpZ;

    float cameraFovDegree;

    double mRotationAngleXZ;
    double mRotationAngleY;

    BOOL inPanMode;
    CGPoint panPrev;
    int panLastDiffX;
    int panLastDiffY;
    double inertiaRatio;
}

// opengl shader and program
-(GLuint) loadShader:(GLenum)shaderType shaderSrc:(NSString *)shaderSrc;
-(GLuint) loadProgram:(NSString*)vShaderSrc fShaderSrc:(NSString*)fShaderSrc;
-(void) useAndAttachLocation:(GLuint)program;

-(void) glCheckError:(NSString *)msg;

// gesture operations
-(void) scale:(float) scale;
-(void) rotate:(int) diffx diffy:(int) diffy;
@end

@implementation GLRenderView

/**
 * Startup method
 * @param frame Size on screen
 */
-(id) initWithFrame:(CGRect)frame{

    self = [super initWithFrame:frame];

    _timerCount = 0;
    _timer = nil;
    _kindInertia = NoneInertia;

    projectionMatrix = GLKMatrix4Identity;
    lookAtMatrix = GLKMatrix4Identity;
    modelMatrix = GLKMatrix4Identity;

    // set initial camera pos and direction
    cameraPosX = 0.0f;
    cameraPosY = 0.0f;
    cameraPosZ = 0.0f;
    cameraDirectionX = 1.0f;
    cameraDirectionY = 0.0f;
    cameraDirectionZ = 0.0f;
    cameraUpX = 0.0f;
    cameraUpY = 1.0f;
    cameraUpZ = 0.0f;

    cameraFovDegree = CAMERA_FOV_DEGREE_INIT;

    inPanMode = FALSE;

    mRotationAngleXZ = 0.0f;
    mRotationAngleY = 0.0f;

    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:context];
    self.context = context;

    if (self) {
        [self registerGestures];
        [self initOpenGLSettings:context];
        half[0] = [[UVSphere alloc] init:SHELL_RADIUS divide:SHELL_DIVIDE rotate:0.0];
        half[1] = [[UVSphere alloc] init:SHELL_RADIUS divide:SHELL_DIVIDE rotate:M_PI];
    }

    NSLog(@"initwithframe frame: x: %f y: %f width %f height %f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);

    return self;
}


/**
 * Gesture registration method
 */
-(void) registerGestures{

    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureHandler:)];
    [panGestureRecognizer setMaximumNumberOfTouches:1];
    [self addGestureRecognizer:panGestureRecognizer];
    NSLog(@"add panGesture.");

    pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureHandler:)];
    [self addGestureRecognizer:pinchGestureRecognizer];
    NSLog(@"add pinchGesture.");

    return;
}

/**
 * Texture registration method
 * @param data Image for registration
 * @param width Image width for registration
 * @param height Image height for registration
 * @param yaw Camera orientation angle
 * @param pitch Camera elevation angle
 * @param roll Camera horizontal angle
 */
-(void) setTexture:(NSMutableData*)data width:(int)width height:(int)height yaw:(float)yaw pitch:(float) pitch roll:(float) roll {

    NSError *error;
    UIImage *image = [UIImage imageWithData:data];
    CGImageRef srcImageRef = [image CGImage];

    // Create CGRect specifying clipping position.
    CGRect leftArea = CGRectMake(0.f, 0.f, image.size.width / 2.f, image.size.height);
    CGRect rightArea = CGRectMake(image.size.width / 2.f, 0.f, image.size.width, image.size.height);

    // Create clipped image using CoreGraphics function.
    CGImageRef leftImageRef = CGImageCreateWithImageInRect(srcImageRef, leftArea);
    CGImageRef rightImageRef = CGImageCreateWithImageInRect(srcImageRef, rightArea);

    GLKTextureInfo *leftTexture = [GLKTextureLoader textureWithCGImage:leftImageRef options:nil error:&error];
    GLKTextureInfo *rightTexture = [GLKTextureLoader textureWithCGImage:rightImageRef options:nil error:&error];

    _textureInfo = @{@GL_TEXTURE0:leftTexture,
                     @GL_TEXTURE1:rightTexture};

    for (id key in _textureInfo) {
        glActiveTexture([key unsignedIntValue]);
        glBindTexture(GL_TEXTURE_2D, ((GLKTextureInfo*)_textureInfo[key]).name);

        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }

    _yaw = yaw;
    _roll = roll;
    _pitch = pitch;

    return;
}

/**
 * OpenGL Initial value setting method
 * @param context OpenGL Context
 */
-(void) initOpenGLSettings:(EAGLContext*)context{

    float viewWidth = self.frame.size.width;
    float viewHeight = self.frame.size.height;

    shaderProgram = [self loadProgram:vertexShader fShaderSrc:fragmentShader];
    [self useAndAttachLocation: shaderProgram];

    //NSLog(@"frame width: %d hegith: %d", (int)self.frame.size.width, (int)self.frame.size.height);

    glClearColor(0.0f, 0.0f, 1.0f, 0.0f);

    viewAspectRatio = viewWidth/viewHeight;
    glViewport(0, 0, viewWidth, viewHeight);

    return;
}

/**
 * Redraw method
 */
-(void) draw{

    projectionMatrix = GLKMatrix4Identity;
    lookAtMatrix = GLKMatrix4Identity;
    modelMatrix = GLKMatrix4Identity;

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    cameraDirectionX = (float) (cos(mRotationAngleXZ)*cos(mRotationAngleY));
    cameraDirectionZ = (float) (sin(mRotationAngleXZ)*cos(mRotationAngleY));
    cameraDirectionY = (float) sin(mRotationAngleY);

    //NSLog(@"camera direction: %f %f %f", cameraDirectionX, cameraDirectionY, cameraDirectionZ);

    projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(cameraFovDegree), viewAspectRatio, Z_NEAR, Z_FAR);
    lookAtMatrix = GLKMatrix4MakeLookAt(cameraPosX, cameraPosY, cameraPosZ,
                                        cameraDirectionX, cameraDirectionY, cameraDirectionZ,
                                        cameraUpX, cameraUpY, cameraUpZ);

    GLKMatrix4 elevetionAngleMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(_pitch), 0, 0, 1);
    modelMatrix = GLKMatrix4Multiply(modelMatrix, elevetionAngleMatrix);
    GLKMatrix4 horizontalAngleMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(_roll), 1, 0, 0);
    modelMatrix = GLKMatrix4Multiply(modelMatrix, horizontalAngleMatrix);

    glEnableVertexAttribArray(aPosition);
    glEnableVertexAttribArray(aUV);

    glUniformMatrix4fv(uModel, 1, GL_FALSE, modelMatrix.m);
    [self glCheckError:@"glUniform4fv model"];
    glUniformMatrix4fv(uView, 1, GL_FALSE, lookAtMatrix.m);
    [self glCheckError:@"glUniform4fv viewmatrix"];
    glUniformMatrix4fv(uProjection, 1, GL_FALSE, projectionMatrix.m);
    [self glCheckError:@"glUniform4fv projectionmatrix"];

    for (int i = 0; i < 2; ++i) {
        glUniform1i(uTex, i);
        [half[i] draw:aPosition uv:aUV];
    }

    glDisableVertexAttribArray(aPosition);
    glDisableVertexAttribArray(aUV);

    return;
}

/**
 * Handler when touch start is detected
 * @param touches Touch information
 * @param event Event
 */
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{

    [_timer invalidate];
    _timer = nil;
    _timerCount = 0;

    inPanMode = false;

    //CGPoint startPos = [[touches anyObject] locationInView:self];
    //NSLog(@"touchesBegan:startPos x = %f, y = %f", startPos.x, startPos.y);

    return;
}

/**
 * Handler when touch is detected
 * @param touches Touch information
 * @param event Event
 */
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    //CGPoint movePos = [[touches anyObject] locationInView:self];
    //NSLog(@"touchesMoved x = %f, y = %f", movePos.x, movePos.y);
    return;
}

/**
 * Handler when touch exit is detected
 * @param touches Touch information
 * @param event Event
 */
-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    //NSLog(@"touchesEnded");
    return;
}

/**
 * Multiple gesture detection compatibility setting method
 * @param gestureRecognizer Gesture that sent the message to the delegate
 * @param otherGestureRecognizer Partner gesture recognized at the same time
 */
-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {

    return NO;
}

/**
 * Pinch operation compatibility handler
 * @param recognizer Recognizer object for gesture operations
 */
-(void) pinchGestureHandler:(UIPinchGestureRecognizer*)recognizer {

    [self scale:[recognizer scale]];
    //NSLog(@"pinchHandler state = %d, zoom = %f, scale = %f", [sender state], zoom, [sender scale]);

    return;
}

/**
 * Pan operation compatibility handler
 * @param recognizer Recognizer object for gesture operations
 */
-(void) panGestureHandler:(UIPanGestureRecognizer*)recognizer {

    CGPoint cur = [recognizer translationInView:self];

    switch ([recognizer state]) {
    case UIGestureRecognizerStateEnded:
        //NSLog(@"pan gesture ended");
        [_timer invalidate];
        _timerCount = 0;
        if(_kindInertia != NoneInertia) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:KNUM_INTERVAL_INERTIA
                            target:self
                            selector:@selector(timerInfo:)
                            userInfo:nil
                            repeats:YES];
        }
        break;
    default:
        if (inPanMode) {
            panLastDiffX = cur.x - panPrev.x;
            panLastDiffY = cur.y - panPrev.y;

            panPrev = cur;
            [self rotate:-panLastDiffX diffy:panLastDiffY];
        }
        else {
            inPanMode = true;
            panPrev = cur;
        }
        break;
    }

    //NSLog(@"pan handler state %d pos %f %f", [recognizer state], cur.x, cur.y);
    return;
}

/**
 * Timer setting method
 * @param timer Setting target timer
 */
-(void) timerInfo:(NSTimer *)timer
{
    int diffX = 0;
    int diffY = 0;

    if (_timerCount == 0) {
        inertiaRatio = 1.0;
        switch (_kindInertia) {
        case ShortInertia:
            inertiaRatio = WEAK_INERTIA_RATIO;
            break;
        case LongInertia:
            inertiaRatio = STRONG_INERTIA_RATIO;
            break;
        }
    } else if(_timerCount > 150) {
        [_timer invalidate];
        _timer = nil;
        _timerCount = 0;
        return;
    } else {
        diffX = panLastDiffX*(1.0/_timerCount)*inertiaRatio;
        diffY = panLastDiffY*(1.0/_timerCount)*inertiaRatio;

        [self rotate:-diffX diffy:diffY];
    }

    //NSLog(@"********** timerInfo : %d lastx %d lasty %d x %d y %d ratio %f **********",
    //      _timerCount, panLastDiffX, panLastDiffX, diffX, diffY, inertiaRatio);
    _timerCount++;

    return;
}


/**
 * Zoom in/Zoom out method
 * @param ratio Zoom in/zoom out ratio
 */
-(void) scale:(float) ratio {

    if (ratio < 1.0) {
        cameraFovDegree = cameraFovDegree * (SCALE_RATIO_TICK_EXPANSION);
        if (cameraFovDegree > CAMERA_FOV_DEGREE_MAX) {
            cameraFovDegree = CAMERA_FOV_DEGREE_MAX;
        }
    }
    else {
        cameraFovDegree = cameraFovDegree * (SCALE_RATIO_TICK_REDUCTION);
        if (cameraFovDegree < CAMERA_FOV_DEGREE_MIN) {
            cameraFovDegree = CAMERA_FOV_DEGREE_MIN;
        }
    }

    //NSLog(@"cameraFovDegree: %f", cameraFovDegree);

    return;
}

/**
 * Rotation method
 * @param diffx Rotation amount (y axis)
 * @param diffy Rotation amount (xy plane)
 */
-(void) rotate:(int) diffx diffy:(int) diffy {

    float xz;
    float y;

    xz = (float)diffx / DIVIDE_ROTATE_X;
    y = (float)diffy / DIVIDE_ROTATE_Y;
    mRotationAngleXZ += xz;
    mRotationAngleY += y;
    if (mRotationAngleY > (M_PI/2)) {
        mRotationAngleY = (M_PI/2);
    }
    if (mRotationAngleY < -(M_PI/2)) {
        mRotationAngleY = -(M_PI/2);
    }

    //NSLog(@"rotation angle: %f %f", mRotationAngleXZ, mRotationAngleY);
    return;
}

/**
 * Method for creating OpenGL shader
 *
 * @param shaderType Shader type
 * @param shaderSrc Shader source
 */
-(GLuint) loadShader:(GLenum)shaderType shaderSrc:(NSString *)shaderSrc {

    GLuint shader;
    GLint compiled;
    const char* shaderRealSrc = [shaderSrc cStringUsingEncoding:NSUTF8StringEncoding];

    shader = glCreateShader(shaderType);
    if (0 == shader) {
        return 0;
    }

    glShaderSource(shader, 1, &shaderRealSrc, NULL);
    glCompileShader(shader);
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

    if (!compiled) {

        GLint infoLen = 0;

        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);

        if (infoLen > 1) {
            char *infoLog = malloc(sizeof(char) * infoLen);

            glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
            NSLog(@"Error compiling shader:\n%s\n", infoLog);

            free(infoLog);
        }

        glDeleteShader(shader);
        return 0;
    }

    return shader;
}


/**
 * Program creation function for OpenGL
 * @param vShaderSrc Vertex shader source
 * @param fShaderSrc Fragment shader source
 */
-(GLuint) loadProgram:(NSString*)vShaderSrc fShaderSrc:(NSString*)fShaderSrc {

    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
    GLint linked;

    // load the vertex shader
    vertexShader = [self loadShader:GL_VERTEX_SHADER shaderSrc:vShaderSrc];
    if (vertexShader == 0) {
        return 0;
    }
    // load fragment shader
    fragmentShader = [self loadShader:GL_FRAGMENT_SHADER shaderSrc:fShaderSrc];
    if (fragmentShader == 0) {
        glDeleteShader(vertexShader);
        return 0;
    }

    // create the program object
    program = glCreateProgram();
    if (program == 0) {
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        return 0;
    }

    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);

    // link the program
    glLinkProgram(program);

    // check the link status
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {

        GLint infoLen = 0;

        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);

        if (infoLen > 1) {
            char *infoLog = malloc (sizeof(char) * infoLen);

            glGetProgramInfoLog(program, infoLen, NULL, infoLog);
            NSLog(@"Error linking program:\n%s\n", infoLog);

            free(infoLog);
        }

        glDeleteProgram(program);
        return 0;
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    return program;
}

/**
 * Program validation and various shader variable validation methods for OpenGL
 * @param program OpenGL Program variable
 */
-(void) useAndAttachLocation:(GLuint) program {

    glUseProgram(program);
    [self glCheckError:@"glUseProgram"];

    aPosition = glGetAttribLocation(program, "aPosition");
    [self glCheckError:@"glGetAttribLocation position"];
    aUV = glGetAttribLocation(program, "aUV");
    [self glCheckError:@"glGetAttribLocation uv"];

    uProjection = glGetUniformLocation(program, "uProjection");
    [self glCheckError:@"glGetUniformLocation projection"];
    uView = glGetUniformLocation(program, "uView");
    [self glCheckError:@"glGetUniformLocation view"];
    uModel = glGetUniformLocation(program, "uModel");
    [self glCheckError:@"glGetUniformLocation model"];
    uTex = glGetUniformLocation(program, "uTex");
    [self glCheckError:@"glGetUniformLocation texture"];

    return;
}

/**
 * OpenGL Method for OpenGL error detection
 * @param msg Output character string at detection
 */
-(void) glCheckError:(NSString *) msg {
    GLenum error;

    while (GL_NO_ERROR != (error = glGetError())) {
        NSLog(@"GLERR: %d %@¥n", error, msg);
    }

    return;
}

- (void)tearDown {

    GLKTextureInfo *leftTexture = [_textureInfo objectForKey:@GL_TEXTURE0];
    GLKTextureInfo *rightTexture = [_textureInfo objectForKey:@GL_TEXTURE1];

    if (nil != leftTexture) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(leftTexture.target, 0);
        GLuint t[] = {leftTexture.name};
        glDeleteTextures(1, t);
    }
    if (nil != rightTexture) {
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(rightTexture.target, 0);
        GLuint t[] = {rightTexture.name};
        glDeleteTextures(1, t);
    }
    self.context = nil;
}
@end
