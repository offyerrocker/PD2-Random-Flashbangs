# Installation
1. Drop the `Random Flashbangs` folder inside your mods directory.
2. Create a folder named `FlashBang Packs` inside your mods directory.

# Installing flashbang packs
* Drop all folders that contain a file named `meta.json` inside the `FlashBang Packs` directory.

# Creating your own flashbang pack
To create a flashbang pack you must create a folder inside the `FlashBang Packs` directory located in `mods/`, the folder must contain a `meta.json` file.

Inside said file there must be an array that contains a list of dictionaries, each dictionary defines one flashbang effect that will be added with the pack and inside the dictionary you have to link the assets the flash will use.

**Example:**
```json
[ // list of flashbangs that this pack adds.
    { // flashbang 1
        // can contain both texture and movie files, if a flashbang has both types, it will be randomly decided if it uses a texture or a movie file each time it gets triggered.
        "movies": [ "lobster_rainbow.movie" ],
        "textures": [ "lobster.texture" ],
        "sounds": [ "lobster.ogg", "lobster_dubstep.ogg" ] // supports multiple files which will be randomly chosen when this flashbang item gets rolled.
    },
    { // flashbang 2
        "textures": [ "mytexture.texture" ]
    }
]
```
