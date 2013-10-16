#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <stdlib.h>

#import <Cocoa/Cocoa.h>

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) {
    @autoreleasepool {

//    NSString *_content = [NSString stringWithContentsOfURL:(__bridge NSURL *)url encoding:NSUTF8StringEncoding error:nil];
    NSURL *url2=(__bridge NSURL*) url;
    NSLog(@"inurl = %@",url2); // its printing null

    NSString *fullpath=[url2 path];
    NSString *fullpath_esc = [fullpath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];

    NSString *nbname=[[url2 path] lastPathComponent];
    
    char cmd[10000]="";
    char outfname[1000]="";
    char outurlcstr[1000]="";
    
    sprintf(outfname, "/tmp/%s.html", nbname.UTF8String);
    sprintf(outurlcstr, "file://localhost%s", outfname);
    sprintf(cmd, "/Library/Frameworks/Python.framework/Versions/2.7/bin/ipython nbconvert --to html %s --stdout > %s", [fullpath_esc cStringUsingEncoding:NSASCIIStringEncoding], outfname);
    
//    fullpath_esc.cStringUsingEncoding(NSASCIIStringEncoding);
    
    
    
//    [NSString stringWithUTF8String:<#(const char *)#>]
    NSLog(@"cmd = %@", [NSString stringWithUTF8String:cmd]);
    system(cmd);
    
    NSString *outstr=[NSString stringWithUTF8String:outurlcstr];
//    NSURL *outurl=[NSURL URLWithString:outstr];
    NSURL *outurl=[NSURL URLWithString:outstr];
    
    NSLog(@"outurl = %@",outurl);

    NSString *htmlcontent = [NSString stringWithContentsOfURL:(NSURL *)outurl encoding:NSUTF8StringEncoding error:nil];

//    NSLog(@"html = %@",htmlcontent); // its printing null

//ff    printf(htmlcontent.UTF8String);
    /*
    FILE *f=fopen(fname, "w");
    fwrite(_content.UTF8String, sizeof(char), strlen(_content.UTF8String), f);
    fclose(f);
    char cmd[10000]="";
    char outfname[1000]="";
    sprintf(cmd, "ipython nbconvert --to html %s --stdout > %s.html", fname, fname);
    sprintf(outfname, "%s.html", fname);
    
//    sprintf(ipython nbconvert --to html ~/Google\ Drive/sleep_stop/notebooks/connection_map.ipynb --stdout > hallo
    system(cmd);
    NSString *out=[NSString stringWithUTF8String:(const char *) outfname];
    NSURL *outurl=[NSURL URLWithString:out];
    NSString *htmlcontent = [NSString stringWithContentsOfURL:(NSURL *)outurl encoding:NSUTF8StringEncoding error:nil];
    */
    
    // Put metadata and attachment in a dictionary
    NSDictionary *properties = @{ // properties for the HTML data
                                 (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
                                 };
    
  //  QLPreviewRequestSetDataRepresentation(preview,(__bridge CFDataRef)[_content dataUsingEncoding:NSUTF8StringEncoding],kUTTypePlainText,NULL);
    QLPreviewRequestSetDataRepresentation(preview,
                                          (__bridge CFDataRef)[htmlcontent dataUsingEncoding:NSUTF8StringEncoding],
//                                          kUTTypePlainText, NULL);
                                          kUTTypeHTML,
                                          (__bridge CFDictionaryRef)properties);
    }
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Implement only if supported
}