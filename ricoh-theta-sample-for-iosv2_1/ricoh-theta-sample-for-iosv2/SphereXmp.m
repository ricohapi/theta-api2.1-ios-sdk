/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "SphereXmp.h"

static const NSString *XMP_START_ELEMENT = @"<x:xmpmeta";
static const NSString *XMP_END_ELEMENT = @"</x:xmpmeta>";
static NSString* const XMP_TAG_NAME_YAW = @"GPano:PoseHeadingDegrees";
static NSString* const XMP_TAG_NAME_PITCH = @"GPano:PosePitchDegrees";
static NSString* const XMP_TAG_NAME_ROLL = @"GPano:PoseRollDegrees";

/**
 * XMP information class included in image data
 * The read information is kept in the properties.
 */
@interface SphereXmp() <NSXMLParserDelegate>
{
    BOOL _isFoundYaw;
    BOOL _isFoundPitch;
    BOOL _isFoundRoll;
    BOOL _result;
}
@end

@implementation SphereXmp

/**
 * Start analysis
 * @param original Image data
 * @return Analysis successful?
 */
- (BOOL)parse:(NSData*)original
{
    _isFoundYaw = NO;
    _isFoundPitch = NO;
    _isFoundRoll = NO;
    _result = NO;
    
    NSData *startElement = [XMP_START_ELEMENT dataUsingEncoding:NSASCIIStringEncoding];
    NSData *endElement = [XMP_END_ELEMENT dataUsingEncoding:NSASCIIStringEncoding];
    NSUInteger startXmpIndex = [self indexOf:startElement in:original from:0];
    NSUInteger endXmpIndex = [self indexOf:endElement in:original from:startXmpIndex];
    NSData *subData = [original subdataWithRange:NSMakeRange(startXmpIndex, endXmpIndex + endElement.length)];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:subData];
    parser.delegate = self;
    
    // Start analysis
    [parser parse];
    return _result;
}

/**
 * Delegates called when XML tags are read during successive processes
 * @param parser XML parser
 * @param elementName Element name
 * @param namespaceURI Name space URI
 * @param qName Modified name
 * @param attributeDict Attribute dictionary
 */
- (void) parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
     attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:XMP_TAG_NAME_YAW]) {
        _isFoundYaw =YES;
    } else if ([elementName isEqualToString:XMP_TAG_NAME_PITCH]) {
        _isFoundPitch = YES;
    } else if ([elementName isEqualToString:XMP_TAG_NAME_ROLL]) {
        _isFoundRoll =YES;
    }
}

/**
 * Delegates called when character strings other than XML tags are read during successive processes
 * @param parser XML parser
 * @param string Read character string
 */
- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (_isFoundYaw) {
        _yaw=string;
        _isFoundYaw = NO;
    } else if (_isFoundPitch) {
        _pitch = string;
        _isFoundPitch = NO;
    } else if (_isFoundRoll) {
        _roll = string;
        _isFoundRoll = NO;
    }
}

/**
 * Delegate called when XML analysis is successful
 * @param parser XML parser
 */
-(void) parserDidEndDocument:(NSXMLParser *)parser
{
    _result = YES;
}

/**
 * Delegate called when XML analysis fails
 * @param parser XML parser
 * @param parseError Error information
 */
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    _result = NO;
}

/**
 * Search position of specific data pattern
 * @param sub Searched data
 * @param original Searched data
 * @param startIndex Search start position
 * @return The position where the searched data starts. "0" is returned if there are no hits.
 */
- (NSUInteger)indexOf:(NSData*)sub in:(NSData*)original from:(NSUInteger)startIndex
{
    Byte temporary[sub.length];
    NSUInteger maxSearch = original.length - sub.length;
    for (NSUInteger i = startIndex; i <= maxSearch; ++i) {
        [original getBytes:temporary range:NSMakeRange(i, sub.length)];
        if (!memcmp(temporary, sub.bytes, sub.length)) {
            return i;
        }
    }
    return 0;
}
@end
