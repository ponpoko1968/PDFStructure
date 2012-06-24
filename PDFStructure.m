//
//  PDFStructure.m
//
//  Created by Shuji OCHI <ponpoko1968@gmail.com> on 10/09/02.
//

#import "PDFStructure.h"
@interface PDFStructure()

-(int) listPages:(int)_pageNum pageNumDict:(NSMutableDictionary*) pageNumDict pagesArray:(CGPDFArrayRef) pagesArray;
- (void) listNames:(NSMutableDictionary*) result srcArray:(CGPDFArrayRef) a;
- (void) listOutlines:(int)depth pointerDict:(NSDictionary*) pointerDict pageNumDict:(NSDictionary*) pageNumDict result:(NSMutableArray*) result srcDict:(CGPDFDictionaryRef) dict;
-(void) dumpTocInternal:(NSArray*)array;
@end

@implementation PDFStructure

@synthesize tableOfContents=tableOfContents_;

-(id) initWithCGPDFDocument:(CGPDFDocumentRef) document {
  if( nil != ( self = [super init] ) ){
    document_ = document;
    CFRetain(document_);
    tableOfContents_= [NSMutableArray array];
    [tableOfContents_ retain];
  }
  return self;
}

-(void) dealloc {
  CFRelease( document_ );
  [tableOfContents_ release];
  [super dealloc];
}

-(BOOL) buildStructure{

  NSMutableDictionary* pointerDict = [NSMutableDictionary dictionaryWithCapacity:100];
  NSMutableDictionary* pageNumDict = [NSMutableDictionary dictionaryWithCapacity:100];


  CGPDFDictionaryRef catalog=CGPDFDocumentGetCatalog( document_ );

  if(!catalog){
    return NO;
  }
  
  Log(@"%p", catalog);
  
  CGPDFDictionaryRef  names =NULL;
  CGPDFDictionaryGetDictionary(catalog, "Names",&names );
  
  CGPDFDictionaryRef  dests = NULL;
  if (names) {
    CGPDFDictionaryGetDictionary(names, "Dests", &dests );    
  }
  CGPDFArrayRef destKids = NULL;
  if( dests ){
    CGPDFDictionaryGetArray(dests, "Kids", &destKids );
  }
  CGPDFDictionaryRef pages = NULL;

  CGPDFDictionaryGetDictionary(catalog, "Pages", &pages );    

  if (!pages) {
    return NO;
  }
  
  CGPDFArrayRef pagesArray = NULL;
  CGPDFDictionaryGetArray(pages, "Kids", &pagesArray );
  CGPDFDictionaryRef  outlines = NULL;
  CGPDFDictionaryGetDictionary(catalog, "Outlines", &outlines );

  if( !outlines ){
    return NO;
  }
  
  CGPDFDictionaryRef  first = NULL;
  CGPDFDictionaryGetDictionary(outlines, "First", &first );
  
  if(!first ){
    return NO;
  }

  Log(@"***** list pages ****");
  [self listPages:0  pageNumDict:pageNumDict pagesArray:pagesArray];

  if (destKids) {
    Log(@"**** list names ****");
    [self listNames:pointerDict srcArray:destKids];
  }
  
  Log(@"**** list outlines ****");
  [self listOutlines:0 pointerDict:pointerDict pageNumDict:pageNumDict result:tableOfContents_ srcDict:first];
  return YES;
}


-(void)dumpToc{
  [self dumpTocInternal:tableOfContents_];
}

- (void)dumpTocInternal:(NSArray*) _array {
    for( NSDictionary* page in _array ){
      NSArray* array;
      Log(@"%@ --- p.%d",[page objectForKey:@"title"],[[page objectForKey:@"pageNumber"] intValue]);
      if( nil != (array = [page objectForKey:@"Kids"]) ){
	[self dumpTocInternal:array];
    }
  }
}


// Outlines/FirstツリーをスキャンしてTocを完成させる
- (void) listOutlines:(int) depth pointerDict:(NSDictionary*) pointerDict pageNumDict:(NSDictionary*) pageNumDict result:(NSMutableArray*) result srcDict:(CGPDFDictionaryRef) dict  {

  CGPDFStringRef dest;
  CGPDFStringRef title;
  CGPDFDictionaryRef dictA;
  NSMutableDictionary* page = nil;

  if(CGPDFDictionaryGetString(dict, "Title", &title )){

    NSString* titleString = [(NSString*)CGPDFStringCopyTextString(title) autorelease];

    char indentBuf[BUFSIZ];
    int x;
    for (x = 0; x < depth && x < BUFSIZ-1; x++) {
      indentBuf[x] = ' ';
    }
    indentBuf[x] = '\0';

    if(CGPDFDictionaryGetString(dict, "Dest", &dest )){ // Dest文字列から間接的にページオブジェクトを引っ張る場合
      NSString* destString = [NSString stringWithCString:(const char*)CGPDFStringGetBytePtr(dest) encoding:NSASCIIStringEncoding];
      NSString* pointerString = [pointerDict valueForKey:destString];
      if( pointerString ){
	page = [NSMutableDictionary
		 dictionaryWithObjects:[NSArray arrayWithObjects:titleString,[pageNumDict valueForKey:pointerString],nil]
		 forKeys: [NSArray arrayWithObjects:@"title",@"pageNumber",nil] ];
	[result addObject:page];

      }

    }
    else if(CGPDFDictionaryGetDictionary(dict, "A", &dictA )){
      CGPDFArrayRef arrayD;
      CGPDFDictionaryRef dict0;
      if( CGPDFDictionaryGetArray(dictA, "D", &arrayD ) &&
	  CGPDFArrayGetDictionary(arrayD, 0, &dict0 ) ){
	page = [NSMutableDictionary
		 dictionaryWithObjects:[NSArray arrayWithObjects:titleString,[pageNumDict valueForKey:[NSString stringWithFormat:@"%p",dict0 ]],nil]
		 forKeys: [NSArray arrayWithObjects:@"title",@"pageNumber",nil] ];
	[result addObject:page];
//	int pageNum = [[pageNumDict valueForKey:[NSString stringWithFormat:@"%p",dict0 ]] intValue];
	//Log(@"%s %s%@ => p.%d",__FUNCTION__,indentBuf,titleString, pageNum);

      }
    }
  }

  CGPDFDictionaryRef first;
  CGPDFDictionaryRef next;
  if(CGPDFDictionaryGetDictionary(dict,"First",&first)){
    NSMutableArray* array = [NSMutableArray array];
    [page setValue:array forKey:@"kids"];
    //    listOutlines(depth+1,pointerDict,pageNumDict,array,first);
    [self listOutlines:depth+1 pointerDict:pointerDict pageNumDict:pageNumDict result:array srcDict:first];
  }
  if (CGPDFDictionaryGetDictionary(dict,"Next",&next)) {
    // listOutlines(depth,pointerDict,pageNumDict,result,next);
    [self listOutlines:depth pointerDict:pointerDict pageNumDict:pageNumDict result:result srcDict:next];
  }
}

//Catalog/Namesツリーをスキャンして、D(Destination文字列)をキー、ページオブジェクトへのポインタを値にした辞書を作成して返す
- (void) listNames:(NSMutableDictionary*) result srcArray:(CGPDFArrayRef) a{
  int cnt = CGPDFArrayGetCount (a);
  for ( int i = 0; i < cnt; i++ ){
    CGPDFDictionaryRef dict;
    CGPDFArrayGetDictionary(a, i, &dict );
    CGPDFArrayRef array;

    if( CGPDFDictionaryGetArray( dict, "Kids", &array ) ){
      //listNames(result,array);
      [self listNames:result srcArray:array];
    }else {
      CGPDFArrayRef names;
      if ( ! CGPDFDictionaryGetArray( dict, "Names", &names ) ) {
	return;
      }
      int cnt = CGPDFArrayGetCount (names );

      for ( int i = 0; i < cnt; i++ ){
	CGPDFStringRef s;
	if (i%2 == 0) {

	  CGPDFArrayGetString(names, i, &s );
	  //Log(@"%d: name = %s",__LINE__,CGPDFStringGetBytePtr(s));
	}else {
	  CGPDFDictionaryRef pageDict;
	  if ( CGPDFArrayGetDictionary(names, i, &pageDict ) ) {
	    CGPDFArrayRef a;
	    CGPDFDictionaryGetArray(pageDict, "D", &a);
	    CGPDFDictionaryRef d;

	    CGPDFArrayGetDictionary(a, 0, &d);
	    [result setObject:[NSString stringWithFormat:@"%p",d]
		    forKey:[NSString stringWithCString:(const char*)CGPDFStringGetBytePtr(s)
					      encoding:NSASCIIStringEncoding] ];
	  }
	}
      }
    }
  }
}

// Catalog/Pagesエントリからページの一覧を取得
// Pageオブジェクトへのポインタをキー、ページ番号を値とした辞書を返す
//int listPages(int _pageNum,NSMutableDictionary* pageNumDict,  CGPDFArrayRef pagesArray ) {
- (int)listPages:(int)_pageNum pageNumDict:(NSMutableDictionary*) pageNumDict pagesArray:(CGPDFArrayRef) pagesArray  {
  int cnt = CGPDFArrayGetCount (pagesArray );

  int pageNum = _pageNum;
  for ( int i = 0; i < cnt; i++ ){

    CGPDFDictionaryRef pageDict;
    CGPDFArrayGetDictionary(pagesArray, i, &pageDict );
    const char *typeString;
    if(CGPDFDictionaryGetName(pageDict, "Type", &typeString ) ) {
      //Log(@"Type=%s", typeString);

      if( strcmp("Pages",typeString) == 0 ){
	CGPDFArrayRef kidsArray;
	CGPDFDictionaryGetArray(pageDict, "Kids",&kidsArray );
	//pageNum = listPages( pageNum, pageNumDict, kidsArray );
	pageNum = [self listPages:pageNum pageNumDict:pageNumDict pagesArray: kidsArray];

      }else if(strncmp("Page",typeString,strlen("Page"))==0 ){
	//Log(@"%s:%d",__FUNCTION__,__LINE__);

	pageNum++;

	[pageNumDict setValue:[NSNumber numberWithInt:pageNum]
		       forKey:[NSString stringWithFormat:@"%p",pageDict] ];
	//Log(@"%s:%d",__FUNCTION__,__LINE__);
	// for debug
	CGPDFObjectRef contents;
	
	CGPDFDictionaryGetObject(pageDict, "Contents", &contents);
	
	//Log(@"%s:%d contents type = %d",__FUNCTION__,__LINE__,CGPDFObjectGetType(contents));
	/*
	CGPDFStreamRef st;
	CGPDFArrayGetStream(contents,1,&st);
	Log(@"%s:%d st=%p",__FUNCTION__,__LINE__,st);
	CGPDFDictionaryRef streamDict;
	streamDict = CGPDFStreamGetDictionary(st);
	Log(@"%s:%d",__FUNCTION__,__LINE__);

	CGPDFInteger length;
	CGPDFDictionaryGetInteger( streamDict, "Length", &length);
	Log(@"%s:%d",__FUNCTION__,__LINE__);
	*/

      }else{
	continue;
      }
    }
  }
  return pageNum;
}

@end
