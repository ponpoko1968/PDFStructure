//
//  PDFStructure.h
//
//  Created by Shuji OCHI <ponpoko1968@gmail.com> on 10/09/02.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PDFStructure : NSObject {
  @private
  CGPDFDocumentRef document_;
  NSMutableArray* tableOfContents_;
}

@property (nonatomic, retain, readonly ) NSArray* tableOfContents;
-(void)dumpToc;
-(id) initWithCGPDFDocument:(CGPDFDocumentRef) document;
-(BOOL) buildStructure;




@end
