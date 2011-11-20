//
//  QSFirefoxPlugIn.h
//  QSFirefoxPlugIn
//

#import <QSCore/QSObject.h>
#import "QSFirefoxPlugIn.h"
#import <QSCore/QSParser.h>
#import "FMDatabase.h"
#import "FMResultSet.h"

#define kQSFirefoxPlugInType @"QSFirefoxPlugInType"

@interface QSFirefoxPlugIn : NSObject
{
}
@end

@interface QSFirefoxBookmarksParser : QSParser
{
}
@end

@interface QSFirefoxHistoryParser : QSParser
{
}
@end

/**
 Simple class to access Firefox's places.sqlite DB.
 It contains common code from QSFirefoxBookmarksParser and QSFirefoxHistoryParser
 */
@interface QSFirefoxPlacesParser : NSObject
{
}
/**
 Execute an SQL query on the Firefox places.sqlite DB.
 @param query the SQL query. Must contain output fieldnames "url" and "title".
 @param path file path to the places.sqlite DB (something like ~/Library/Application Support/Firefox/Profiles/.../places.sqlite)
 @returns an array of QS-URL-Objects, or empty array on error
 */
+ (NSArray *) executeSql:(NSString *)query onFile:(NSString *)path;

@end

