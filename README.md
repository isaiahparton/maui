# maui
My awesome user interface

# principles
- Be simple
- Be responsive
- Only display what the user wants to see

# how it works
The core `UI` has pointers to an 'IO' and a 'Painter' struct which represent the platform and renderer respectively
	A root layer is created when `begin_ui()` is called
