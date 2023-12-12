# maui
Stands for marvelous user interface.  An immediate-mode gui library for my projects and maybe for you?  It's still in early development, but the end goal is a somewhat stylish and polished interface suitable for utility applications like sound mixers, database access and point of sale.

# how it works

Maui is sent input by your platform of choice and sends vertices to your renderer of choice.  Currently includes working backends for *glfw* and *opengl* 

The layout is based on rectangle cutting, but self-growing layouts are also possible, I'm looking for ways to improve this still.

Maui generates individual font glyphs and rasterized shapes on demand as they are needed, updating it's atlas texture as needed.

# things to add
- Loading user images
- Color scheme editor
- Theme editor
- Integrate my database library **datos** for spreadsheets and such

# showcase

![](https://github.com/isaiahparton/maui/blob/main/demo.gif)