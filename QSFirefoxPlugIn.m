//
//  QSFirefoxPlugIn.m
//  QSFirefoxPlugIn
//

#import "QSFirefoxPlugIn.h"

@implementation QSFirefoxPlugIn

- (void)performJavaScript:(NSString *)jScript {
	//NSLog(@"JAVASCRIPT perform: %@",jScript);
	NSDictionary *errorDict=nil;
	NSAppleScript *script=[[[NSAppleScript alloc]initWithSource:[NSString stringWithFormat:@"tell application \"Firefox\" to Get URL \"%@\"",jScript]]autorelease];
	if (errorDict) NSLog(@"Load Script: %@",[errorDict objectForKey:@"NSAppleScriptErrorMessage"]);
	else [script executeAndReturnError:&errorDict];
	if (errorDict) NSLog(@"Run Script: %@",[errorDict objectForKey:@"NSAppleScriptErrorMessage"]);
}

- (id)resolveProxyObject:(id)proxy {
	// reading Firefox's sessionsstore.js
    static NSString *path = nil;
    if (!path) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:[@"~/Library/Application Support/Firefox/Profiles/*/sessionstore.js" stringByResolvingWildcardsInPath]]) {
            path = [[@"~/Library/Application Support/Firefox/Profiles/*/sessionstore.js" stringByResolvingWildcardsInPath] retain];
        } else if ([fm fileExistsAtPath:[@"~/Library/Application Support/Firefox/Profiles/*/sessionstore-backups/recovery.js" stringByResolvingWildcardsInPath]]) {
            path = [[@"~/Library/Application Support/Firefox/Profiles/*/sessionstore-backups/recovery.js" stringByResolvingWildcardsInPath] retain];
        }
    }
    if (!path) {
        QSShowAppNotifWithAttributes(@"QSFirefoxPlugin", NSLocalizedStringForThisBundle(@"Unable to locate Session Store", @"notif title"), NSLocalizedStringForThisBundle(@"Unable to locate the Session Store file for Firefox", @"notif message"));
        return nil;
    }
	NSError *err;
	NSString *jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
	if (!jsonString) {
		NSLog(@"Error when reading file: %@", err);
	}
	
	// parsing JSON
	NSDictionary *sessionstore = [jsonString objectFromJSONString];
	
	// traversing JSON path to current web page
	NSArray *windows = [sessionstore objectForKey:@"windows"];
	int selectedWindow =[[sessionstore objectForKey:@"selectedWindow"] intValue];
	NSDictionary *window = [windows objectAtIndex:selectedWindow-1];
	NSArray *tabs = [window objectForKey:@"tabs"];
	int selectedTab =[[window objectForKey:@"selected"] intValue];
	NSDictionary *tab = [tabs objectAtIndex:selectedTab-1];
	NSArray *entries = [tab objectForKey:@"entries"];
	NSDictionary *entry = [entries lastObject];
    NSString *title = [entry objectForKey:@"title"];
	NSString *url = [entry objectForKey:@"url"];
	
	return [QSObject URLObjectWithURL:url title:title];
}


@end

@implementation QSFirefoxBookmarksParser
- (BOOL)validParserForPath:(NSString *)path {
	return [[path lastPathComponent] isEqualToString:@"places.sqlite"];
}

- (NSArray *)objectsFromPath:(NSString *)path withSettings:(NSDictionary *)settings {
	NSString *query = @"SELECT "
						"bookmarks.title AS title, "
						"places.url AS url "
						"FROM moz_bookmarks AS bookmarks "
						"LEFT JOIN moz_places AS places ON places.id = bookmarks.fk "
						"WHERE bookmarks.fk IS NOT NULL "
						"AND bookmarks.title IS NOT NULL "
						"ORDER BY bookmarks.title";
	
	return [QSFirefoxPlacesParser executeSql:query onFile:path];
}
@end

@implementation QSFirefoxHistoryParser
- (BOOL)validParserForPath:(NSString *)path {
	return [[path lastPathComponent] isEqualToString:@"places.sqlite"];
}

- (NSArray *)objectsFromPath:(NSString *)path withSettings:(NSDictionary *)settings {
	NSString *query = [NSString stringWithFormat:@"SELECT DISTINCT "
					   "places.title AS title, "
					   "places.url AS url "
					   "FROM moz_historyvisits AS history "
					   "LEFT JOIN moz_places AS places ON places.id = history.place_id "
					   "ORDER BY visit_date DESC "
					   "LIMIT %d", 
					   [[settings objectForKey:@"historySize"] intValue]];

	return [QSFirefoxPlacesParser executeSql:query onFile:path];
}
@end


@implementation QSFirefoxPlacesParser

+ (NSArray *) executeSql:(NSString *)query onFile:(NSString *)path {
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:0];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *tempPath = [NSTemporaryDirectory() stringByAppendingString:@"QSFirefoxPlaces.sqlite"];
	NSError *err;
	BOOL status;
	
	// make sure tmp-copy of places.sqlite isn't there
	status = [manager removeItemAtPath:tempPath error:&err];
	
	// copy places.sqlite so it wont be locked when Firefox is running
	status = [manager copyItemAtPath:path toPath:tempPath error:&err];
	if (!status) {
		NSLog(@"Error while copying Firefox places.sqlite: %@", err);
	}
	
	// open places.sqlite DB
	FMDatabase *db = [FMDatabase databaseWithPath:tempPath];
	if (![db open]) {
		NSLog(@"Could not open Firefox's places.sqlite DB.");
		return objects;
	}
	
	// execute SQL query
	FMResultSet *rs = [db executeQuery:query];
	if ([db hadError]) {
		NSLog(@"Error while reading Firefox's places.sqlite DB. Error %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		return objects;
	}
	
	// build QSObjects
	NSString *url, *title;
	QSObject *newObject;
	while ([rs next]) {
		title = [rs stringForColumn:@"title"];
		url = [rs stringForColumn:@"url"];
		
		newObject = [QSObject URLObjectWithURL:url title:title];
		[objects addObject:newObject];
	}
	
	// close DB
	[rs close];
	[db close];		
	
	// delete tmp-copy of places.sqlite
	status = [manager removeItemAtPath:tempPath error:&err];
	if (!status) {
		NSLog(@"Error while removing copy of Firefox places.sqlite: %@", err);
	}
	
	return objects;
}


@end


