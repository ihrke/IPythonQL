#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <stdlib.h>

#import <Cocoa/Cocoa.h>

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);
bool debug=false;

void FixUnixPath() {
    // adapted from http://stackoverflow.com/questions/208897/find-out-location-of-an-executable-file-in-cocoa
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        NSString *userShell = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHELL"];
        if(debug) NSLog(@"User's shell is %@", userShell);
        
        // avoid executing stuff like /sbin/nologin as a shell
        BOOL isValidShell = NO;
        for (NSString *validShell in [[NSString stringWithContentsOfFile:@"/etc/shells" encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if ([[validShell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:userShell]) {
                isValidShell = YES;
                break;
            }
        }
        
        if (!isValidShell) {
            if(debug) NSLog(@"Shell %@ is not in /etc/shells, won't continue.", userShell);
            return;
        }
        NSTask *task=[[NSTask alloc] init];
        [task setLaunchPath: userShell];
        [task setArguments: [NSArray arrayWithObjects: @"-l", @"-c", @"echo $PATH", nil]];
        NSPipe *pipe=[[NSPipe alloc] init];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        [task launch];
        NSData *data = [file readDataToEndOfFile];
        NSString* newStr = [NSString stringWithUTF8String:[data bytes]];
        NSString *userPath=[newStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        /* this doesn't work for some reason; I use the preceding which is just a more verbose version of that line*/
         /*
        NSString *userPath = [[NSTask stringByLaunchingPath:userShell withArguments:[NSArray arrayWithObjects:@"-c", @"echo $PATH", nil] error:nil]
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
         */
        if (userPath.length > 0 && [userPath rangeOfString:@":"].length > 0 && [userPath rangeOfString:@"/usr/bin"].length > 0) {
            // BINGO!
            if(debug) NSLog(@"User's PATH as reported by '%@' is '%@'", userShell, userPath);
            setenv("PATH", [userPath fileSystemRepresentation], 1);
        }
    });
}

NSString* getIPython(){
        NSString *userShell = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHELL"];
        if(debug) NSLog(@"User's shell is %@", userShell);
        
        // avoid executing stuff like /sbin/nologin as a shell
        BOOL isValidShell = NO;
        for (NSString *validShell in [[NSString stringWithContentsOfFile:@"/etc/shells" encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if ([[validShell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:userShell]) {
                isValidShell = YES;
                break;
            }
        }
        
        if (!isValidShell) {
            if(debug) NSLog(@"Shell %@ is not in /etc/shells, won't continue.", userShell);
        }
        NSTask *task=[[NSTask alloc] init];
        [task setLaunchPath: userShell];
        [task setArguments: [NSArray arrayWithObjects: @"-l", @"-c", @"which ipython", nil]];
        NSPipe *pipe=[[NSPipe alloc] init];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        [task launch];
        NSData *data = [file readDataToEndOfFile];
        NSString* ipython = [NSString stringWithUTF8String:[data bytes]];
//        ipython=[ipython stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        ipython=[ipython stringByReplacingOccurrencesOfString:@"\\n" withString:@""];
    

    // my own implementation of removing the trailing \n that is sometimes there and sometimes not
    //  for some reason the fancy NS-functions above fail... wtf??
    char *ip=(char*)[ipython UTF8String];
    for(int i=0; i<strlen(ip); i++ ){
        if(ip[i]=='\n')
            ip[i]='\0';
    }
    ipython=[NSString stringWithUTF8String:ip];
    
        if(debug) NSLog(@"fct(IPython)='%@'", ipython);
        return ipython;
}
/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */
OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) {
    @autoreleasepool {
        if (QLPreviewRequestIsCancelled(preview))
            return noErr;

        NSURL *url2=(__bridge NSURL*) url;
        if(debug) NSLog(@"inurl = %@",url2);
        NSString *fullpath=[url2 path];
    
        FixUnixPath();

        NSTask *task;
        task = [[NSTask alloc] init];
        NSString *ipython=getIPython();
        if(debug) NSLog(@"IPython='%@'", ipython);
        
            //ipython=@"/Library/Frameworks/Python.framework/Versions/2.7/bin/ipython";

        [task setLaunchPath: ipython]; //@"ipython"];
        
        BOOL exists = [[NSFileManager defaultManager] isReadableFileAtPath:[task launchPath]];//  isExecutableFileAtPath:[task launchPath]];
        NSLog(@"%@ '%@'\n", exists ? @"Exists" : @"Does Not Exist", [task launchPath]);
        
        NSArray *arguments;
        arguments = [NSArray arrayWithObjects: @"nbconvert", @"--to", @"html", @"--output=/tmp/blubberdiblubb123", fullpath, nil];

        [task setArguments: arguments];
        if(debug) NSLog(@"task=%@", [task arguments] );
        

        NSPipe *pipe=[[NSPipe alloc] init];
        NSPipe *errpipe=[[NSPipe alloc] init];
        
        [task setStandardOutput: pipe];
        [task setStandardError: errpipe];
        
        NSFileHandle *file;
        file = [pipe fileHandleForReading];

        NSFileHandle *efile;
        efile = [errpipe fileHandleForReading];
        

        [task launch];
        [task waitUntilExit];
     
        NSData *data;
        data = [file readDataToEndOfFile];

        NSData *edata;
        edata = [efile readDataToEndOfFile];
        
        NSString* newStr = [NSString stringWithUTF8String:[edata bytes]];
        if(debug) NSLog(@"stderr=%@", newStr );
        
        NSURL *ourl = [NSURL fileURLWithPath:@"/tmp/blubberdiblubb123.html"];
        NSString *htmlcontent = [NSString stringWithContentsOfURL:ourl encoding:NSUTF8StringEncoding error:nil];
        
        // Put metadata and attachment in a dictionary
        NSDictionary *properties = @{ // properties for the HTML data
                                     (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                     (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
                                     };
    
        QLPreviewRequestSetDataRepresentation(preview,
                                              (__bridge CFDataRef)[htmlcontent dataUsingEncoding:NSUTF8StringEncoding],
                                              kUTTypeHTML,
                                              (__bridge CFDictionaryRef)properties);
    }
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Implement only if supported
}