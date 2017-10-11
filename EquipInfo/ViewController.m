//
//  ViewController.m
//  EquipInfo
//
//  Created by syamaco on 2017/08/14.
//  Copyright © 2017年 syamaco. All rights reserved.
//

#import "ViewController.h"
#import "inc/RscMgr.h"

#define BUF_SIZE (256 * 32)

@interface ViewController () <RscMgrDelegate>
{
    IBOutlet UILabel* statusLabel;
    
    IBOutlet UISegmentedControl* viewMode;
    
    IBOutlet UILabel* rxCountLabel;
    IBOutlet UITextView* rxDataText;

    RscMgr* rscMgr;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    // Initialize RedparkSerialCommunication Manager
    rscMgr = [[RscMgr alloc] init];
    [rscMgr setDelegate:self];

    // Comm Params
    [rscMgr setBaud:115200];
    [rscMgr setDataSize:kDataSize8];
    [rscMgr setParity:kParityNone];
    [rscMgr setStopBits:kStopBits1];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)send:(UITextField*)sender
{
    [rscMgr writeString:[sender.text stringByAppendingString:@"\r\n"]];
}

- (IBAction)change:(UISegmentedControl*)sender
{
    rxDataText.text = @"";
}

- (IBAction)ls:(id)sender
{
    // ドキュメントディレクトリ
    NSArray* documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentDirectory = [documentDirectories lastObject];
    
    // ドキュメントディレクトリにあるファイルリスト
    NSError* error = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray* files = [fileManager contentsOfDirectoryAtPath:documentDirectory error:&error];
    for (NSString* file in files) {
        NSDictionary* attr = [fileManager attributesOfItemAtPath:[documentDirectory stringByAppendingPathComponent:file] error:nil];
        NSNumber* size = [attr objectForKey:NSFileSize];
        [self log:[NSString stringWithFormat:@"%@ %@", file, size]];
    }
}

- (IBAction)dd:(id)sender
{
    // ホームディレクトリ
    //NSString* homeDir = NSHomeDirectory();

    // ドキュメントディレクトリ
    NSArray* documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentDirectory = [documentDirectries lastObject];

    NSString* filePath = [documentDirectory stringByAppendingPathComponent:@"test.bin"];
    [self log:filePath];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:filePath]) {
        if (![fileManager createFileAtPath:filePath contents:[NSData data] attributes:nil]) {
            [self log:@"Cannot create file."];
            return;
        }
    }
    
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!fileHandle) {
        [self log:@"File handle error."];
        return;
    }
    
    [fileHandle seekToEndOfFile];
    
    static UInt8 buf[1024 * 1024];
    
    for (int i = 0; i < sizeof(buf); i++) {
        buf[i] = i & 0xff;
    }

    for (int n = 0; n < 100; n++) {
        [fileHandle writeData:[NSData dataWithBytes:buf length:sizeof(buf)]];
    }

    //効率化のためにファイルに書き込まれずにキャッシュされる場合があるらしいのでsynchronizeFileで書き込み
    [fileHandle synchronizeFile];
    [fileHandle closeFile];
    
    [self log:@"Done."];
}

- (IBAction)rm:(id)sender
{
    // ドキュメントディレクトリ
    NSArray* documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentDirectory = [documentDirectries lastObject];

    NSString* filePath = [documentDirectory stringByAppendingPathComponent:@"test.bin"];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:filePath]) {
        if (![fileManager removeItemAtPath:filePath error:nil]) {
            [self log:@"Cannot remove file."];
        } else {
            [self log:@"Done."];
        }
    } else {
        [self log:@"Not exist."];
    }
}

- (void)log:(NSString*)s
{
    rxDataText.text = [rxDataText.text stringByAppendingFormat:@"%@\n", s];
}

// Redpark Serial Cable has been connected and/or application moved to foreground.
// protocol is the string which matched from the protocol list passed to initWithProtocol:
- (void) cableConnected:(NSString *)protocol
{
    statusLabel.text = @"Connected";
    statusLabel.textColor = [UIColor greenColor];
}

// Redpark Serial Cable was disconnected and/or application moved to background
- (void) cableDisconnected
{
    statusLabel.text = @"Disconnected";
    statusLabel.textColor = [UIColor redColor];
    }

// serial port status has changed
// user can call getModemStatus or getPortStatus to get current state
- (void) portStatusChanged
{
    
}

// bytes are available to be read (user should call read:, getDataFromBytesAvailable, or getStringFromBytesAvailable)
- (void) readBytesAvailable:(UInt32)length
{
    UInt8 buf[256];

    UInt32 total = 0;
    
    while (length)
    {
        int len = [rscMgr read:buf length:sizeof(buf)];
        length -= len;
        total += len;
    }

    rxCountLabel.text = [NSString stringWithFormat:@"%zd", total];
    //rxDataText.text = [rxDataText.text stringByAppendingString:@"\n"];
    
    buf[total < sizeof(buf) - 1 ? total : sizeof(buf) - 1] = 0;
    rxDataText.text = [rxDataText.text stringByAppendingString:[self dump:buf length:total]];
    
    if (rxDataText.text.length > 0)
    {
        NSRange bottom = NSMakeRange(rxDataText.text.length - 1, 1);
        [rxDataText scrollRangeToVisible:bottom];
    }
}

- (NSString*)dump:(UInt8*)data length:(UInt32)length
{
    if (viewMode.selectedSegmentIndex == 0)
    {
        NSMutableString* s = [[NSMutableString alloc] initWithCapacity:BUF_SIZE];
        
        for (int i = 0; i < length; i++)
        {
            if (i % 16 == 0) [s appendFormat:@"\n%04x", i];
            [s appendFormat:@" %02X", data[i]];
        }
        
        return s;
    }
    else
    {
        return [NSString stringWithUTF8String:(const char *)data];
    }
}

@end
