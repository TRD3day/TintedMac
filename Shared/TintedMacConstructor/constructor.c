//
//  constructor.c
//  TintedMacInject
//
//  C constructor for dylib injection
//

#include <string.h>
#include <unistd.h>
#include <libproc.h>
#include <dlfcn.h>
#include <sys/stat.h>

// Forward declaration of Swift function
extern void tinted_mac_dylib_constructor(void);

// Dynamic GUI detection - check if this process is actually a GUI application
static int is_gui_process(void) {
    char process_path[PROC_PIDPATHINFO_MAXSIZE];

    // Get full process path
    if (proc_pidpath(getpid(), process_path, sizeof(process_path)) <= 0) {
        return 0; // Failed to get process path, skip
    }

    // Extract just the executable name from full path
    char *basename = strrchr(process_path, '/');
    if (basename) {
        basename++; // Skip the '/'
    } else {
        basename = process_path;
    }

    // Skip our own components
    if (strstr(basename, "TintedMac") != NULL) {
        return 0;
    }

    // Check 1: Is this process in an .app bundle?
    if (strstr(process_path, ".app/") != NULL) {
        return 1; // Definitely a GUI app
    }

    // Check 2: Is AppKit framework loaded?
    void* appkit = dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_LAZY | RTLD_NOLOAD);
    if (!appkit) {
        return 0; // AppKit not loaded, probably CLI
    }
    dlclose(appkit);

    // Check 3: Is this a system daemon/agent/helper?
    if (strstr(basename, "daemon") != NULL ||
        strstr(basename, "agent") != NULL ||
        strstr(basename, "helper") != NULL ||
        strstr(basename, "service") != NULL) {
        return 0;
    }

    // Check 4: Does it end with 'd' (common daemon pattern)?
    size_t len = strlen(basename);
    if (len > 1 && basename[len-1] == 'd') {
        return 0;
    }

    // Check 5: Is it in a typical CLI location?
    if (strstr(process_path, "/usr/bin/") != NULL ||
        strstr(process_path, "/bin/") != NULL ||
        strstr(process_path, "/usr/local/bin/") != NULL) {
        return 0; // Likely a CLI tool
    }

    // Check 6: Check if the process has a window server connection
    // This is a more definitive test for GUI apps
    void* coregraphics = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY | RTLD_NOLOAD);
    if (!coregraphics) {
        return 0; // No CoreGraphics, probably not GUI
    }
    dlclose(coregraphics);

    // If we get here, it's likely a GUI process
    return 1;
}

// C constructor function - called automatically when dylib is loaded
__attribute__((constructor))
void tinted_mac_c_constructor(void) {
    // Only call Swift initialization if this looks like a GUI process
    if (is_gui_process()) {
        tinted_mac_dylib_constructor();
    }
    // If we don't inject, we exit silently without calling Swift
}
