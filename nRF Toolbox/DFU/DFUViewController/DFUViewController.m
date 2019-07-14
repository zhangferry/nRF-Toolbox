/*
 * Copyright (c) 2015, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DFUViewController.h"
#import "ScannerViewController.h"

#import "Constants.h"
#import "AppFilesViewController.h"
#import "UserFilesViewController.h"
#import "Utility.h"

@interface DFUViewController ()

/*!
 * This property is set when the device has been selected on the Scanner View Controller.
 */
@property (strong, nonatomic) CBPeripheral *selectedPeripheral;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) DFUServiceController *controller;
@property (strong, nonatomic) DFUFirmware *selectedFirmware;
@property (strong, nonatomic) NSURL *selectedFileUrl;
@property (strong, nonatomic) NSURL *selectedFileDataUrl;

@property (weak, nonatomic) IBOutlet UILabel *fileName;
@property (weak, nonatomic) IBOutlet UILabel *fileSize;

@property (weak, nonatomic) IBOutlet UILabel *uploadStatus;
@property (weak, nonatomic) IBOutlet UIProgressView *progress;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectFileButton;
@property (weak, nonatomic) IBOutlet UIView *uploadPane;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UILabel *fileType;
@property (weak, nonatomic) IBOutlet UILabel *verticalLabel;
@property (weak, nonatomic) IBOutlet UILabel *deviceName;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;

- (IBAction)uploadPressed;
- (IBAction)aboutButtonClicked:(id)sender;

@end

@implementation DFUViewController

@synthesize deviceName;
@synthesize connectButton;
@synthesize selectedPeripheral;
@synthesize selectedFirmware;
@synthesize fileName;
@synthesize fileSize;
@synthesize uploadStatus;
@synthesize progress;
@synthesize progressLabel;
@synthesize selectFileButton;
@synthesize uploadButton;
@synthesize uploadPane;
@synthesize fileType;
@synthesize selectedFileUrl;
@synthesize selectedFileDataUrl;
@synthesize centralManager;
@synthesize controller;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Rotate the vertical label
    self.verticalLabel.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(-145.0f, 0.0f), (float)(-M_PI / 2));

}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:YES];
    //if DFU peripheral is connected and user press Back button then disconnect it
    if ([self isMovingFromParentViewController] && controller != nil)
    {
        if (![controller abort]) {
            [self logWith:LogLevelApplication message:@"Aborting DFU process failed"];
        }
    }
}

-(void)uploadPressed
{
    if (controller)
    {
        // Pause the upload process. Pausing is possible only during upload, so if the device was still connecting or sending some metadata it will continue to do so,
        // but it will pause just before seding the data.
        [controller pause];

        UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Abort?" message:@"Do you want to abort?" preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* abort = [UIAlertAction
                                actionWithTitle:@"Abort"
                                style:UIAlertActionStyleDestructive
                                handler:^(UIAlertAction * action)
                                {
                                    // Abort upload process
                                    [controller abort];
                                    [alert dismissViewControllerAnimated:YES completion:nil];

                                }];
        UIAlertAction* cancel = [UIAlertAction
                                 actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     // Resume upload
                                     [controller resume];
                                     [alert dismissViewControllerAnimated:YES completion:nil];
                                 }];

        [alert addAction:abort];
        [alert addAction:cancel];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [self performDFU];
    }
}

- (IBAction)aboutButtonClicked:(id)sender {
    [self showAbout:[Utility getDFUHelpText]];
}

-(void)performDFU
{
    [self disableOtherButtons];
    progress.hidden = NO;
    progressLabel.hidden = NO;
    uploadStatus.hidden = NO;
    uploadButton.enabled = NO;

    [self registerObservers];

    // To start the DFU operation the DFUServiceInitiator must be used
    dispatch_queue_t queue = dispatch_queue_create("com.nRF.customQueue", NULL);
    dispatch_queue_t mainQueue = dispatch_get_main_queue();

    DFUServiceInitiator *initiator = [[DFUServiceInitiator alloc] initWithQueue:queue
                                                                  delegateQueue:mainQueue
                                                                  progressQueue:mainQueue
                                                                    loggerQueue:mainQueue];

    initiator = [initiator withFirmware:selectedFirmware]; //recommend

    initiator.forceDfu = [[[NSUserDefaults standardUserDefaults] valueForKey:@"dfu_force_dfu"] boolValue];
    initiator.packetReceiptNotificationParameter = [[[NSUserDefaults standardUserDefaults] valueForKey:@"dfu_number_of_packets"] intValue];
    initiator.logger = self;
    initiator.delegate = self;
    initiator.progressDelegate = self;
    initiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = YES;
    // initiator.peripheralSelector = ... // the default selector is used

    //controller = [initiator start];  deprecated
    controller = [initiator startWithTarget:selectedPeripheral];  //recommend
    [uploadButton setTitle:@"Cancel" forState:UIControlStateNormal];
    uploadButton.enabled = YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"scan"])
    {
        // Set this contoller as scanner delegate
        UINavigationController *nc = segue.destinationViewController;
        ScannerViewController *scannerViewController = (ScannerViewController *)nc.childViewControllerForStatusBarHidden;
        //controller.filterUUID = dfuServiceUUID; - the DFU service should not be advertised. We have to scan for any device hoping it supports DFU.
        scannerViewController.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"FileSegue"])
    {
        UINavigationController* nc = segue.destinationViewController;
        UITabBarController *barController = (UITabBarController*) nc.childViewControllerForStatusBarHidden;
        AppFilesViewController *appFilesVC = [barController.viewControllers firstObject];
        appFilesVC.fileDelegate = self;
        UserFilesViewController* userFilesVC = [barController.viewControllers lastObject];
        userFilesVC.fileDelegate = self;

        if (selectedFileUrl)
        {
            NSString *path = [selectedFileUrl path];
            appFilesVC.selectedPath = path;
            userFilesVC.selectedPath = path;
        }
    }
}

- (void) clearUI
{
    controller = nil;
    selectedPeripheral = nil;

    deviceName.text = @"DEFAULT DFU";
    uploadStatus.text = nil;
    uploadStatus.hidden = YES;
    progress.progress = 0.0f;
    progress.hidden = YES;
    progressLabel.text = nil;
    progressLabel.hidden = YES;

    [uploadButton setTitle:@"Upload" forState:UIControlStateNormal];
    [self enableOrDisableUploadButton];
    [self enableOtherButtons];

    [self unregisterObservers];
}

-(void)enableOrDisableUploadButton
{
    uploadButton.enabled = selectedFirmware && selectedPeripheral;
}

-(void)disableOtherButtons
{
    selectFileButton.enabled = NO;
    connectButton.enabled = NO;
}

-(void)enableOtherButtons
{
    selectFileButton.enabled = YES;
    connectButton.enabled = YES;
}

#pragma mark - Supoprt for background mode

-(void)registerObservers
{
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)])
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:
         [UIUserNotificationSettings
          settingsForTypes: UIUserNotificationTypeAlert|UIUserNotificationTypeSound
          categories:nil]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

-(void)unregisterObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)appDidEnterBackground:(NSNotification *)_notification
{
    // Controller is set when the DFU is in progress
    if (controller)
    {
        [Utility showBackgroundNotification:@"Uploading firmware..."];
    }
}

-(void)appDidEnterForeground:(NSNotification *)_notification
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

#pragma mark - Device selection delegate methods

-(void)centralManager:(CBCentralManager *)manager didPeripheralSelected:(CBPeripheral *)peripheral
{
    selectedPeripheral = peripheral;
    centralManager = manager;
    deviceName.text = peripheral.name;
    [self enableOrDisableUploadButton];
}

#pragma mark - DFU Service delegate methods

-(void)logWith:(enum LogLevel)level message:(NSString *)message
{
    NSLog(@"%ld: %@", (long) level, message);
}

-(void)dfuStateDidChangeTo:(enum DFUState)state
{
    switch (state) {
        case DFUStateConnecting:
            uploadStatus.text = @"Connecting...";
            break;
        case DFUStateStarting:
            uploadStatus.text = @"Starting DFU...";
            break;
        case DFUStateEnablingDfuMode:
            uploadStatus.text = @"Enabling DFU Bootloader...";
            break;
        case DFUStateUploading:
            uploadStatus.text = @"Uploading...";
            break;
        case DFUStateValidating:
            uploadStatus.text = @"Validating...";
            progressLabel.text = nil;
            break;
        case DFUStateDisconnecting:
            uploadStatus.text = @"Disconnecting...";
            break;
        case DFUStateCompleted:
            [Utility showAlert:@"Upload complete"];
            if ([Utility isApplicationStateInactiveORBackground])
            {
                [Utility showBackgroundNotification:@"Upload complete."];
            }
            [self clearUI];
            break;
        case DFUStateAborted:
            [Utility showAlert:@"Upload aborted"];
            [self clearUI];
            break;
        default:
            break;
    }
}

- (void)dfuProgressDidChangeFor:(NSInteger)part outOf:(NSInteger)totalParts to:(NSInteger)progress currentSpeedBytesPerSecond:(double)currentSpeedBytesPerSecond avgSpeedBytesPerSecond:(double)avgSpeedBytesPerSecond{

    NSLog(@"part:%ld, totalParts:%ld, progress:%ld, currentSpeedBytesPerSecond:%f, avgSpeedBytesPerSecond:%f", part, totalParts, progress, currentSpeedBytesPerSecond, avgSpeedBytesPerSecond);
    //打印更新进度
    self.progress.progress = progress / 100.0;
    self.progressLabel.text = [NSString stringWithFormat:@"%ld%% (%ld/%ld)",progress,part,totalParts];
}
- (void)dfuError:(enum DFUError)error didOccurWithMessage:(NSString * _Nonnull)message{

    NSLog(@"Error %ld: %@", (long) error, message);

    [Utility showAlert:message];
    if ([Utility isApplicationStateInactiveORBackground])
    {
        [Utility showBackgroundNotification:message];
    }
    [self clearUI];
}

#pragma mark - File selection delegate methods

-(void)onFileSelected:(NSURL *)url
{
    selectedFileUrl = url;
    selectedFileDataUrl = [NSURL fileURLWithPath:@"file:///var/containers/Bundle/Application/E4F79CED-6495-49B8-95DA-54B0F4E68CC0/nRF%20Toolbox.app/firmwares/X9ET_4.3.0.dat"];
    selectedFirmware = nil;
    fileName.text = nil;
    fileSize.text = nil;
    fileType.text = nil;

    NSString *fileNameComponent = url.lastPathComponent;
    NSString *extension = [[fileNameComponent pathExtension] lowercaseString];

    if ([extension isEqualToString:@"zip"])
    {
        selectedFirmware = [[DFUFirmware alloc] initWithUrlToZipFile:url];

        if (selectedFirmware && selectedFirmware.fileName)
        {
            fileName.text = selectedFirmware.fileName;
            NSData *content = [[NSData alloc] initWithContentsOfURL:url];
            fileSize.text = [NSString stringWithFormat:@"%lu bytes", (long) content.length];
            fileType.text = @"Distribution Packet (ZIP)";
        }
        else
        {
            selectedFirmware = nil;
            selectedFileUrl = nil;
            [Utility showAlert:@"Selected file is not supported."];
        }
        [self enableOrDisableUploadButton];
    }
    else
    {
        // Show a view to select the file type
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UINavigationController *nc = (UINavigationController *) [mainStoryboard instantiateViewControllerWithIdentifier:@"SelectFileType"];
        FileTypeViewController *fileTypeVC = (FileTypeViewController *) nc.childViewControllerForStatusBarHidden;
        fileTypeVC.delegate = self;
        [self presentViewController:nc animated:YES completion:nil];
    }
}

-(void)onFileTypeSelected:(DFUFirmwareType)type
{

    selectedFirmware = [[DFUFirmware alloc] initWithUrlToBinOrHexFile:selectedFileUrl urlToDatFile:nil type:type];
//    selectedFirmware = [[DFUFirmware alloc] initWithUrlToBinOrHexFile:selectedFileUrl urlToDatFile:selectedFileDataUrl type:type];

    if (selectedFirmware && selectedFirmware.fileName)
    {
        fileName.text = selectedFirmware.fileName;
        NSData *content = [[NSData alloc] initWithContentsOfURL:selectedFileUrl];
        fileSize.text = [NSString stringWithFormat:@"%lu bytes", (long) content.length];

        switch (type) {
            case DFUFirmwareTypeSoftdevice:
                fileType.text = @"Softdevice";
                break;
            case DFUFirmwareTypeBootloader:
                fileType.text = @"Bootloader";
                break;
            case DFUFirmwareTypeApplication:
                fileType.text = @"Application";
                break;
            case DFUFirmwareTypeSoftdeviceBootloader:
                fileType.text = @"SD + BL";
                break;
            case DFUFirmwareTypeSoftdeviceBootloaderApplication:
                fileType.text = @"APP + SD + BL";
                break;
        }
    }else{

        selectedFirmware = nil;
        selectedFileUrl = nil;
        [Utility showAlert:@"Selected file is not supported."];
    }
    [self enableOrDisableUploadButton];
}

-(void)onFileTypeNotSelected
{
    selectedFileUrl = nil;
    [self enableOrDisableUploadButton];
}

@end
