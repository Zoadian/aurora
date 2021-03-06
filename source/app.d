import std.stdio;

import std.typecons;

import three;

import std.experimental.logger;

public import derelict.opengl3.gl3;
public import derelict.glfw3.glfw3;
public import derelict.anttweakbar.anttweakbar;
public import derelict.freeimage.freeimage;	
public import derelict.freetype.ft;
public import derelict.assimp3.assimp;

public import std.experimental.logger;

import three.gl.renderer;

import three.window;
import three.camera;
import three.scene;

enum idendityMatrix = Matrix4([
	0.005f, 0.0f, 0.0f, 0.0f, 
	0.0f, 0.005f, 0.0f, 0.0f, 
	0.0f, 0.0f, 0.005f, 0.0f, 
	0.0f, 0.0f, 0.0f, 1.0f, 
]);

void main() {
	Window window;	
	Viewport viewport;
	Scene scene;
	Camera camera;
	GlRenderTarget renderTarget;
	//	OpenGlTiledDeferredRenderer renderer;
	Renderer renderer;
	bool keepRunning = true;

	//------------------------------------------------
	// Load and Construct Rendering Pipeline
	//------------------------------------------------
	DerelictGL3.load();
	DerelictGLFW3.load();
	DerelictFI.load();
	//	DerelictFT.load();
	DerelictASSIMP3.load();
	DerelictAntTweakBar.load();
	if(!glfwInit()) throw new Exception("Initialising GLFW failed"); scope(exit) glfwTerminate();

	window.construct("Three.d", 1600, 900); scope(exit) window.destruct();
	
	try {
		GLVersion glVersion = DerelictGL3.reload();
		import std.conv : to;
		writeln("Reloaded OpenGL Version: ", to!string(glVersion)); 
	} catch(Exception e) {
		writeln("Reloading OpenGl failed: " ~ e.msg);
	}

	//	static FT_Library _s_freeTypeLibrary
	//	if(!FT_Init_FreeType(&_s_freeTypeLibrary)) throw new Exception("Initialising FreeType failed"); scope(exit) FT_Done_FreeType(_s_freeTypeLibrary);
	if(TwInit(TW_OPENGL_CORE, null) == 0) throw new Exception("Initialising AntTweakBar failed"); scope(exit) TwTerminate();


	viewport.construct(); scope(exit) viewport.destruct();
	scene.construct(); scope(exit) scene.destruct();
	camera.construct(); scope(exit) camera.destruct();
	renderTarget.construct(window.width, window.height); scope(exit) renderTarget.destruct();
	renderer.construct(window.width, window.height); scope(exit) renderer.destruct();

	//------------------------------------------------
	// Create Scene
	//------------------------------------------------
	//TODO: check file exists
	scene.loadModel("F:/Coding/models/Collada/duck.dae");
//	scene.loadModel("F:/Coding/models/Collada/cube.dae");
//	scene.loadModel("F:/Coding/models/Collada/teapots.DAE");
	log("vertexCount: ", scene.vertexCount, " (", scene.vertexCount * VertexData.sizeof / 1024," KiB)");
	log("indexCount: ", scene.indexCount, " (", scene.indexCount * IndexData.sizeof / 1024," KiB)");
	log("meshCount: ", scene.meshCount);
	log("modelCount: ", scene.modelCount);

	scene.instanceData ~= InstanceData(idendityMatrix);
	scene.instanceDescriptor ~= InstanceDescriptor(0, 0, 1);

	//------------------------------------------------
	// Generate TweakBar
	//------------------------------------------------
	TwWindowSize(window.width, window.height);
	auto tweakBar = TwNewBar("TweakBar");
	
	
	//------------------------------------------------
	// Connect Window callbacks
	//------------------------------------------------
	window.onKey = (ref Window rWindow, Key key, ScanCode scanCode, KeyAction action, KeyMod keyMod) {
		if(window is window && action == KeyAction.Pressed) {
			if(key == Key.Escape) {
				keepRunning = false;
			}
		}
	};
	
	window.onClose = (ref Window rWindow) {
		keepRunning = false;
	};
	
	window.onSize = (ref Window rWindow, int width, int height) {
		TwWindowSize(width, height);		
	};
	
	window.onPosition = (ref Window rWindow, int x, int y) {
	};
	
	window.onButton = (ref Window rWindow , int button, ButtonAction action) {
		TwMouseAction twaction = action == ButtonAction.Pressed ? TW_MOUSE_PRESSED : TW_MOUSE_RELEASED;
		TwMouseButtonID twbutton;
		
		switch(button) {
			default:
			case GLFW_MOUSE_BUTTON_LEFT: twbutton = TW_MOUSE_LEFT; break;
			case GLFW_MOUSE_BUTTON_RIGHT: twbutton = TW_MOUSE_RIGHT; break;
			case GLFW_MOUSE_BUTTON_MIDDLE: twbutton = TW_MOUSE_MIDDLE; break;			
		}
		
		TwMouseButton(twaction, twbutton);		
	};
	
	window.onCursorPos = (ref Window rWindow, double x, double y) {
		TwMouseMotion(cast(int)x, window.height - cast(int)y);
	};
	


	//------------------------------------------------
	// Main Loop
	//------------------------------------------------
	ulong frameCount = 0;
	glfwSetTime(0);

	while(keepRunning) {
		window.pollEvents();
		
		window.makeAktiveRenderWindow();

		renderer.renderOneFrame(scene, camera, renderTarget, viewport);

		debug{ renderer.blitGBufferToScreen(); }

//		TwDraw();
		
		window.swapBuffers();
		
		++frameCount;
		if(frameCount % 10 == 0) {
			auto fps = cast(double)frameCount / glfwGetTime();
			log("FPS: ", fps);
			frameCount = 0;
			glfwSetTime(0);
		}
	}
}







/+++++++

//======================================================================================================================
// 
//======================================================================================================================
struct Slice(T) {
	T* data;
	size_t length;
}




//======================================================================================================================
// 
//======================================================================================================================
struct PersistentlyMappedBuffer(T) {
	GLuint bo;
	GLenum target;
	Slice!T data;
	alias Atom = T;
}

void create(T)(out PersistentlyMappedBuffer!T pmb, GLuint count, GLenum target, GLbitfield createFlags, GLbitfield mapFlags) {
	pmb.target = target;
	glCheck!glGenBuffers(1, &pmb.bo);
	glCheck!glBindBuffer(target, pmb.bo);
	glCheck!glBufferStorage(target, T.sizeof * count, null, createFlags);
	pmb.data.data = cast(T*)glMapBufferRange(target, 0, T.sizeof * count, mapFlags);
	pmb.data.length = count;
	if (!pmb.data.data) {
		throw new Exception("glMapBufferRange failed, probable bug.");
	}
}

void destroy(T)(ref PersistentlyMappedBuffer!T pmb) {
	glCheck!glBindBuffer(pmb.target, mName);
	glCheck!glUnmapBuffer(pmb.target);
	glCheck!glDeleteBuffers(1, &mName);

	pmb = GlPersistentlyMappedBuffer!T.init;
}


//
////======================================================================================================================
//// 
////======================================================================================================================
//struct GlCircularBufferView(T) {
//	GlPersistentlyMappedBuffer!T _buffer;
//	GLsizeiptr _head;
//}








//======================================================================================================================
// 
//======================================================================================================================
struct DrawArraysIndirectCommand {
	GLuint vertexCount;
	GLuint instanceCount;
	GLuint firstVertex;
	GLuint baseInstance;
}

struct DrawElementsIndirectCommand {
	GLuint count;
	GLuint instanceCount;
	GLuint firstIndex;
	GLuint baseVertex;
	GLuint baseInstance;
}

struct PerInstanceRenderData {
}

struct MeshDataRef {
}

struct PerInstanceDataRef {
}

struct Mesh {
	size_t meshDataRef;
	InstanceData[] instanceData;
}

struct MeshInstance {
	size_t meshRef;
	size_t meshInstanceRef;
}

struct Renderer {
	MeshData[] meshData;
	Mesh[] meshes;
	MeshInstance[] meshInstances;






	PersistentlyMappedBuffer!DrawElementsIndirectCommand commandBuffer;
	PersistentlyMappedBuffer!TransformationMatrix perInstanceBuffer;

	void renderOneFrame(Instances instances) {


		auto instanceCount = 0;
		// write draw commands
		DrawElementsIndirectCommand* cmds = commandBuffer.reserve(instanceCount);
		foreach(size_t i = 0; i < instanceCount; ++i) {
			DrawElementsIndirectCommand* cmd = &cmds[u];
			cmd->count = mIndexCount;
			cmd->instanceCount = 1;
			cmd->firstIndex = 0;
			cmd->baseVertex = 0;
			cmd->baseInstance = mUseShaderDrawParameters ? 0 : u;
		}

		// write per instance 
		perInstanceBuffer.reserve(instances.length);
		foreach() {
		}

		glCheck!glMultiDrawElementsIndirect(GL_TRIANGLES, GL_UNSIGNED_SHORT, mCommands.GetHeadOffset(), xformCount, 0);
	}
}








/++++










struct GlPeristentBuffer {
}







struct GlRingBuffer {
	GLuint bo;
}

struct ParamPerInstanceRingBuffer {
	GLuint bo;
}


struct Renderer {
	CommandRingBuffer commandRb;
	ParamPerInstanceRingBuffer paramPerInstanceRb;
}












struct MeshStorageManager(MeshLayout = DefaultVertexLayout) {
	struct Slice {
		size_t offset;
		size_t length;
	}

	struct MeshStorage {
		Slice vertexSlice;
		Slice indexSlice;
	}

	GLuint vao;
	GLuint vbo;
	GLuint ibo;
	MeshStorage[] meshes;
}


struct MeshInstance {
}








struct MappedPersistentBuffer {
	GLuint vbo;
	void* data;
}

void create(out MappedPersistentBuffer mpb, GLsizeiptr bufferSize) {
	glCheck!glGenVertexArrays(1, &mpb.vbo);

	GLbitfield mapFlags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
	GLbitfield createFlags = mapFlags | GL_MAP_DYNAMIC_STORAGE_BIT;

	glCheck!glBindBuffer(GL_ARRAY_BUFFER, mpb.vbo);
	glCheck!glBufferStorage(GL_ARRAY_BUFFER, bufferSize, null, createFlags);
	mpb.data = glCheck!glMapBufferRange(GL_ARRAY_BUFFER, 0, bufferSize, mapFlags);
}




++++/






//======================================================================================================================
// 
//======================================================================================================================
struct SOAVector3 {
	SoA!float x;
	SoA!float y;
	SoA!float z;
}

struct SOAQuaternion {
	SoA!float x;
	SoA!float y;
	SoA!float z;
	SoA!float w;
}




//======================================================================================================================
// 
//======================================================================================================================
void main() {
	Window window;
	Viewport viewport;
	Scene scene;
	Camera camera;
	RenderTarget renderTarget;
	OpenGlTiledDeferredRenderer renderer;
	bool keepRunning = true;


	//------------------------------------------------
	// Load and Construct Rendering Pipeline
	//------------------------------------------------
	DerelictGL3.load();
	DerelictGLFW3.load();
	DerelictFI.load();
//	DerelictFT.load();
	DerelictASSIMP3.load();
	DerelictAntTweakBar.load();
	if(!glfwInit()) throw new Exception("Initialising GLFW failed"); scope(exit) glfwTerminate();

	window.construct("Three.d", 1600, 900); scope(exit) window.destruct();

	try {
		GLVersion glVersion = DerelictGL3.reload();
		import std.conv : to;
		writeln("Reloaded OpenGL Version: ", to!string(glVersion)); 
	} catch(Exception e) {
		writeln("Reloading OpenGl failed: " ~ e.msg);
	}

//	static FT_Library _s_freeTypeLibrary
//	if(!FT_Init_FreeType(&_s_freeTypeLibrary)) throw new Exception("Initialising FreeType failed"); scope(exit) FT_Done_FreeType(_s_freeTypeLibrary);
	if(TwInit(TW_OPENGL_CORE, null) == 0) throw new Exception("Initialising AntTweakBar failed"); scope(exit) TwTerminate();

	viewport.construct(); scope(exit) window.destruct();
	scene.construct(); scope(exit) window.destruct();
	camera.construct(); scope(exit) window.destruct();
	renderTarget.construct(window.width, window.height); scope(exit) renderTarget.destruct();
	renderer.construct(window.width, window.height); scope(exit) renderer.destruct();



	//############################
	//############################
	//############################
	//############################


	GlPersistentlyMappedBuffer!DefaultVertexData vertexBuffer;

	vertexBuffer.create(1024, GL_ARRAY_BUFFER, 0, 0);


	//############################
	//############################
	//############################
	//############################





	//------------------------------------------------
	// Create Scene
	//------------------------------------------------
	scene.mesh.loadModel("C:/Coding/models/Collada/duck.dae");


	//------------------------------------------------
	// Generate TweakBar
	//------------------------------------------------
	TwWindowSize(window.width, window.height);
	auto tweakBar = TwNewBar("TweakBar");


	//------------------------------------------------
	// Connect Window callbacks
	//------------------------------------------------
	window.onKey = (ref Window rWindow, Key key, ScanCode scanCode, KeyAction action, KeyMod keyMod) {
		if(window is window && action == KeyAction.Pressed) {
			if(key == Key.Escape) {
				keepRunning = false;
			}
		}
	};

	window.onClose = (ref Window rWindow) {
		keepRunning = false;
	};

	window.onSize = (ref Window rWindow, int width, int height) {
		TwWindowSize(width, height);		
	};

	window.onPosition = (ref Window rWindow, int x, int y) {
	};

	window.onButton = (ref Window rWindow , int button, ButtonAction action) {
		TwMouseAction twaction = action == ButtonAction.Pressed ? TW_MOUSE_PRESSED : TW_MOUSE_RELEASED;
		TwMouseButtonID twbutton;
		
		switch(button) {
			default:
			case GLFW_MOUSE_BUTTON_LEFT: twbutton = TW_MOUSE_LEFT; break;
			case GLFW_MOUSE_BUTTON_RIGHT: twbutton = TW_MOUSE_RIGHT; break;
			case GLFW_MOUSE_BUTTON_MIDDLE: twbutton = TW_MOUSE_MIDDLE; break;			
		}
		
		TwMouseButton(twaction, twbutton);		
	};

	window.onCursorPos = (ref Window rWindow, double x, double y) {
		TwMouseMotion(cast(int)x, window.height - cast(int)y);
	};


	//------------------------------------------------
	// Main Loop
	//------------------------------------------------
	ulong frameCount = 0;
	glfwSetTime(0);
	while(keepRunning) {
		window.pollEvents();

		window.makeAktiveRenderWindow();

		glCheck!glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glCheck!glClearDepth(1.0f);
		glCheck!glClearColor(0, 0.3, 0, 1);

		/*
		foreach(renderTarget) //framebuffer
		foreach(pass)
		foreach(material) //shaders
		foreach(materialInstance) //textures
		foreach(vertexFormat) //vertex buffers
		foreach(object) {
							write uniform data;
							glDrawElementsBaseVertex
						}
		*/		



		renderer.renderOneFrame(scene, camera, renderTarget, viewport);

		TwDraw();

		debug{ renderer.blitGBufferToScreen(); }

		window.swapBuffers();

		++frameCount;
		if(frameCount % 1000 == 0) {
			auto fps = cast(double)frameCount / glfwGetTime();
			log("FPS: ", fps);
			frameCount = 0;
			glfwSetTime(0);
		}
	}
}




/+++


	

struct Vertex {
	float x, y, z;
}

struct Normal {
	float x, y, z;
}

struct UV {
	float u, v;
}


final class Mesh {
public:
	Vertex[] vertexData;
	Normal[] normalData;
	UV[] textureData;
	RGBAf[] colorData;

	VertexArrayObject vao;
	VertexBufferObject!(VertexBufferObjectTarget.Array) vboVertexData;
	VertexBufferObject!(VertexBufferObjectTarget.Array) vboNormalData;
	VertexBufferObject!(VertexBufferObjectTarget.Array) vboTextureData;
	VertexBufferObject!(VertexBufferObjectTarget.Array) vboColorData;

	this(string filePath) {
		writeln("loading scene: ", filePath);
		auto scene = aiImportFile(filePath.toStringz(),	aiProcess_Triangulate);
		writeln("meshes: ", scene.mNumMeshes);
		for(uint m = 0; m < scene.mNumMeshes; ++m) {  
			const(aiMesh*) mesh = scene.mMeshes[m];
			assert(mesh !is null);
			writeln("mesh[", m, "] faces : ", mesh.mNumFaces);
			for (uint f = 0; f < mesh.mNumFaces; ++f) {	 
				const(aiFace*) face = &mesh.mFaces[f];
				assert(face !is null);
				
				for(uint v = 0; v < 3; ++v) {
					aiVector3D p, n, uv; 
					assert(face.mNumIndices > v);
					uint vertex = face.mIndices[v];
					assert(mesh.mNumVertices > vertex);
					p = mesh.mVertices[vertex];
					n = mesh.mNormals[vertex];
					
					// check if the mesh has texture coordinates
					if(mesh.mTextureCoords[0] !is null) {
						uv = mesh.mTextureCoords[0][vertex];
					}
					
					vertexData ~= Vertex(p.x, p.y, p.z);
					normalData ~= Normal(n.x, n.y, n.z);
					textureData ~= UV(uv.x, uv.y);
					colorData ~= RGBAf(n.x, n.y, n.z, 1.0f);
				}
			}
		}
		writeln("unloading scene: ", filePath);
		aiReleaseImport(scene);

		//-----------------------------
		// upload
		writeln("uploading mesh: ", filePath);
		vao = new VertexArrayObject();
		vao.bind();

		writeln("vertex data");
		vboVertexData = new VertexBufferObject!(VertexBufferObjectTarget.Array);
		vboVertexData.bind();
		GLuint attribIndex = 0;
		glBufferData(GL_ARRAY_BUFFER, cast(ptrdiff_t)(Vertex.sizeof * vertexData.length) , vertexData.ptr, GL_STATIC_DRAW);		
		glEnableVertexAttribArray(attribIndex);
		glVertexAttribPointer(attribIndex, 3, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		vboVertexData.unbind();

		writeln("normal data");
		vboNormalData = new VertexBufferObject!(VertexBufferObjectTarget.Array);
		vboNormalData.bind();
		attribIndex = 1;
		glBufferData(GL_ARRAY_BUFFER, cast(ptrdiff_t)(Normal.sizeof * normalData.length) , normalData.ptr, GL_STATIC_DRAW);		
		glEnableVertexAttribArray(attribIndex);
		glVertexAttribPointer(attribIndex, 3, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		vboNormalData.unbind();

		writeln("uv data");
		vboTextureData = new VertexBufferObject!(VertexBufferObjectTarget.Array);
		vboTextureData.bind();
		attribIndex = 2;
		glBufferData(GL_ARRAY_BUFFER, cast(ptrdiff_t)(UV.sizeof * textureData.length) , textureData.ptr, GL_STATIC_DRAW);		
		glEnableVertexAttribArray(attribIndex);
		glVertexAttribPointer(attribIndex, 2, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		vboTextureData.unbind();

		writeln("color data");
		vboColorData = new VertexBufferObject!(VertexBufferObjectTarget.Array);
		vboColorData.bind();
		attribIndex = 3;
		glBufferData(GL_ARRAY_BUFFER, cast(ptrdiff_t)(RGBAf.sizeof * colorData.length) , colorData.ptr, GL_STATIC_DRAW);		
		glEnableVertexAttribArray(attribIndex);
		glVertexAttribPointer(attribIndex, 4, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		vboColorData.unbind();		
		
		vao.unbind();
		writeln("done");
	}
}

void setupTweakbar() {
	writeln("creating TweakBar");
	double time        = 0, dt;              // Current time and enlapsed time
	double turn        = 0;                  // Model turn counter
	double speed       = 0.3;                // Model rotation speed
	int wire           = 0;                  // Draw model in wireframe?
	uint frameCount    = 0;
	double fps    = 0;
	float bgColor[3]   = [0.1f, 0.2f, 0.4f]; // Background color
	ubyte cubeColor[4] = [255, 0, 0, 128];   // Model color (32bits RGBA)
	
	auto quat = Quaternionf(0,0,0,1);
	
	//		auto w = this._window.getBounds()[2];
	//		auto h = this._window.getBounds()[3];
	TwWindowSize(1600, 900);
	
//	// Create a tweak bar
//	auto bar = TwNewBar("TweakBar");
//	TwDefine(" GLOBAL help='This example shows how to integrate AntTweakBar with GLFW and OpenGL.' "); // Message added to the help bar.		
//	// Add 'speed' to 'bar': it is a modifable (RW) variable of type TW_TYPE_DOUBLE. Its key shortcuts are [s] and [S].
//	TwAddVarRW(bar, "speed", TW_TYPE_DOUBLE, &speed, " label='Rot speed' min=0 max=2 step=0.01 keyIncr=s keyDecr=S help='Rotation speed (turns/second)' ");		
//	// Add 'wire' to 'bar': it is a modifable variable of type TW_TYPE_BOOL32 (32 bits boolean). Its key shortcut is [w].
//	TwAddVarRW(bar, "wire", TW_TYPE_BOOL32, &wire, " label='Wireframe mode' key=CTRL+w help='Toggle wireframe display mode.' ");		
//	// Add 'time' to 'bar': it is a read-only (RO) variable of type TW_TYPE_DOUBLE, with 1 precision digit
//	TwAddVarRO(bar, "time", TW_TYPE_DOUBLE, &time, " label='Time' precision=1 help='Time (in seconds).' ");
//	//
//	TwAddVarRO(bar, "frameCount", TW_TYPE_UINT32, &frameCount, " label='FrameCount' precision=1 help='FrameCount (in counts).' ");
//	TwAddVarRO(bar, "fps", TW_TYPE_DOUBLE, &fps, " label='fps' precision=1 help='fps (in fps).' ");		
//	// Add 'bgColor' to 'bar': it is a modifable variable of type TW_TYPE_COLOR3F (3 floats color)
//	TwAddVarRW(bar, "bgColor", TW_TYPE_COLOR3F, &bgColor, " label='Background color' ");		
//	// Add 'cubeColor' to 'bar': it is a modifable variable of type TW_TYPE_COLOR32 (32 bits color) with alpha
//	TwAddVarRW(bar, "cubeColor", TW_TYPE_COLOR32, &cubeColor, " label='Cube color' alpha help='Color and transparency of the cube.' ");
//	//
//	TwAddVarRW(bar, "quaternion", TW_TYPE_QUAT4F, &quat, " label='Cubde color' alpha help='Color anwdwd transparency of the cube.' ");
}

//-----------------
// Create Shaders
enum vertexShaderSource = "
			#version 420 core

			layout(location = 0) in vec3 in_position;
			layout(location = 1) in vec3 in_normal;
			layout(location = 2) in vec2 in_texcoord;
			layout(location = 3) in vec4 in_color;


			out vec4 v_color;	

			out gl_PerVertex 
			{
		    	vec4 gl_Position;
		 	};

			void main()
			{
				gl_Position = vec4(0.005 * in_position.x, 0.005 * in_position.y, 0.005* in_position.z, 1.0);
		    	v_color = in_color;
			}
		";

enum fragmentShaderSource = "
			#version 420 core
			in vec4 v_color;

			out vec4 FragColor;

			void main()
			{
				FragColor = v_color;
			}
		";


auto createShaderPipeline(Shader!(ShaderType.Vertex) vertexShader, Shader!(ShaderType.Fragment) fragmentShader) {	
	assert(vertexShader.isLinked, vertexShader.infoLog());
	assert(fragmentShader.isLinked, fragmentShader.infoLog());

	writeln("a: ");
	auto shaderPipeline = new ShaderPipeline();
	shaderPipeline.bind();
	shaderPipeline.use(vertexShader);
	shaderPipeline.use(fragmentShader);
	writeln("b: ");
	assert(shaderPipeline.isValidProgramPipeline, shaderPipeline.infoLog());
	shaderPipeline.unbind();
	writeln("c: ");
	return shaderPipeline;
}

class Tester {
	Window _window;
	bool _keepRunning = true;

	this() {
		this._window = initThree();
		this._window.onKey.connect!"_onKey"(this);
		this._window.onClose.connect!"_onClose"(this);
	}
	
	~this() {
		import core.memory;
		writeln("GC.collect: ");
		GC.collect();
		//Collect window _AFTER_ everything else
		this._window = null;
		GC.collect();
		deinitThree();
	}

	void run() {
		RGBAf rgg;

		auto mesh = new Mesh("C:/Coding/models/Collada/duck.dae");


		setupTweakbar();

		writeln("creating shaders: ");
		auto vertexShader = new Shader!(ShaderType.Vertex)(vertexShaderSource);
		auto fragmentShader = new Shader!(ShaderType.Fragment)(fragmentShaderSource);
		writeln("creating shader pipeline: ");
		auto shaderPipeline = createShaderPipeline(vertexShader, fragmentShader);


		writeln("connectiong window callbacks: ");
		this._window.onSize.connect!"onSize"(this);
		this._window.onPosition.connect!"onPosition"(this);
		this._window.onButton.connect!"onButton"(this);
		this._window.onCursorPos.connect!"onCursorPos"(this);

		writeln("begin render loop: ");
		//-----------------
		// Render Loop
		glfwSetTime(0);
		while(this._keepRunning) {
					
			this._window.clear(0, 0, 0.5, 1);

			shaderPipeline.bind();
			mesh.vao.bind();
			//vboVertexData.bind();
			glDrawArrays(GL_TRIANGLES, 0, mesh.vertexData.length);
			//vbo.unbind();
			mesh.vao.unbind();
			shaderPipeline.unbind();

			TwDraw();

			this._window.swapBuffers();
			updateWindows();


//			++frameCount;
//			//if(frameCount % 100 == 0) {
//				time = glfwGetTime();
//				fps = cast(double)frameCount / time;
//			//}
		}
	}

	void onSize(Window window, int width, int height) {
		TwWindowSize(width, height);
	}

	void onPosition(Window window, int x, int y) {
	}

	void onButton(Window window , int button, ButtonAction action) {
		TwMouseAction twaction = action == ButtonAction.Pressed ? TW_MOUSE_PRESSED : TW_MOUSE_RELEASED;
		TwMouseButtonID twbutton;

		switch(button) {
			default:
			case GLFW_MOUSE_BUTTON_LEFT: twbutton = TW_MOUSE_LEFT; break;
			case GLFW_MOUSE_BUTTON_RIGHT: twbutton = TW_MOUSE_RIGHT; break;
			case GLFW_MOUSE_BUTTON_MIDDLE: twbutton = TW_MOUSE_MIDDLE; break;			
		}

		TwMouseButton(twaction, twbutton);
	}

	void onCursorPos(Window window, double x, double y) {
		TwMouseMotion(cast(int)x, this._window.getBounds()[3] - cast(int)y);
	}
	
	void stop() {
		this._keepRunning = false;
	}
	
	void _onKey(Window window, Key key, ScanCode scanCode, KeyAction action, KeyMod keyMod) {
		if(window is this._window && action == KeyAction.Pressed) {
			if(key == Key.Escape) {
				this.stop();
			}
		}
	}

	void _onClose(Window window) {
		this.stop();
	}
}


class InputHandler {
private:
	Window _window;
	OpenGlRenderer _renderer;

public:
	this(Window window, OpenGlRenderer renderer) {
		_window = window;
		_renderer = renderer;

		_window.onKey.connect!"_onKey"(this);
		_window.onClose.connect!"_onClose"(this);
		_window.onSize.connect!"_onSize"(this);
		_window.onPosition.connect!"_onPosition"(this);
		_window.onButton.connect!"_onButton"(this);
		_window.onCursorPos.connect!"_onCursorPos"(this);
	}

private:
	void _onKey(Window window, Key key, ScanCode scanCode, KeyAction action, KeyMod keyMod) {
		if(window is _window && action == KeyAction.Pressed) {
			if(key == Key.Escape) {
				_renderer.stop();
			}
		}
	}
	
	void _onClose(Window window) {
		_renderer.stop();
	}

	void _onSize(Window window, int width, int height) {
	}
	
	void _onPosition(Window window, int x, int y) {
	}
	
	void _onButton(Window window , int button, ButtonAction action) {
	}
	
	void _onCursorPos(Window window, double x, double y) {
	}
}

void main() {
	auto window = initThree();
	{
		OpenGlRenderer renderer = new OpenGlRenderer(window);

		InputHandler inputHandler = new InputHandler(window, renderer);

		renderer.run();
	}
	
	import core.memory;
	GC.collect();
	//Collect window _AFTER_ everything else
	this._window = null;
	GC.collect();
	deinitThree();
}


+++/




+++++++/