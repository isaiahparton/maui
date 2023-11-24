# maui
Stands for marvelous user interface.  An immediate-mode gui library for my projects and maybe for you?  It's still in early development, but the end goal is a realistic, stylish and polished interface suitable for utility applications like sound mixers, database access and point of sale.  This is my main project, as it will be used in many others.  I have great plans for its future.

# how it works

Maui is sent input by your platform of choice and sends vertices to your renderer of choice.  Currently includes working backends for *glfw* and *opengl* 

The layout is based on rectangle cutting, but growing layouts is also possible, I'm looking for ways to improve this still.

Maui generates fonts and textures on demand as they are needed, updating a giant 4096x4096 texture.

# roadmap
- Integrate my raster graphics library **orca** for generating cool widget textures
- Loading user images
- Color scheme editor
- Integrate my database library **datos** for spreadsheets and such

# showcase

i'll put stuff here soon