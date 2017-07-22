#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#define CHECK_PROCESS_NAME
#define USE_REAL_PATH
#import "Header.h"
#import <notify.h>
#import "../PSPrefs.x"

NSString *const tweakIdentifier = @"com.PS.MorePredict";
NSString *const maxPadKey = @"UIPredictionExpandedPad";
NSString *const landscapeCountKey = @"UIPredictionCountForLandscape";
NSString *const portraitCountKey = @"UIPredictionCountForPortrait";
NSString *const predictionGapKey = @"UIPredictionGap";
NSString *const barHeightFactorKey = @"UIPredictionBarHeightFactor";

BOOL unhook = NO;

BOOL maxPad;
NSUInteger landscapeCount;
NSUInteger portraitCount;
NSUInteger maxCount;
CGFloat predictionGap;
CGFloat barHeightFactor;

void updateMaxCount() {
    maxCount = MAX(portraitCount, landscapeCount);
}

CGFloat appropriateCellHeight(CGFloat original) {
    CGFloat height = original;
    if (IS_IPAD)
        height = isiOS9Up ? [NSClassFromString(@"UIKeyboardAssistantBar") assistantBarHeight] * 41 / 55 : original; // Huh?
    else {
        NSInteger orientation = [[UIKeyboard activeKeyboard] interfaceOrientation];
        if (orientation == 0)
            orientation = [UIApplication.sharedApplication _frontMostAppOrientation];
        height = [NSClassFromString(@"UIKeyboardPredictionView") predictionViewHeightForState:1 orientation:orientation];
    }
    return height;
}

extern "C" void setCellRect(UIKeyboardPredictionCell *cell, CGRect frame, NSUInteger index, NSUInteger count) {
    BOOL isLast = (index == count - 1);
    BOOL notHeadOrTail = index == 0 || isLast;
    CGFloat gap = [%c(UIKeyboardPredictionView) overlapHeight];
    CGFloat cellWidth = (frame.size.width - (count - 1) * gap) / count;
    CGFloat cellHeight = appropriateCellHeight(frame.size.height);
    CGFloat cellX = index == 0 ? 0 : (index * (cellWidth + gap));
    CGFloat cellY = frame.size.height / 2 - cellHeight / 2;
    CGRect cellFrame = CGRectMake(cellX, cellY, cellWidth, cellHeight);
    CGFloat activeWidth = cellWidth + (notHeadOrTail ? (2 * gap) : gap);
    CGRect activeFrame = CGRectMake(cellX, cellY, activeWidth, cellHeight);
    CGFloat baseWidth = cellWidth + (notHeadOrTail ? 0.0 : gap);
    CGRect baseFrame = CGRectMake(cellX, cellY, baseWidth, cellHeight);
    cell.activeFrame = activeFrame;
    cell.collapsedFrame = baseFrame;
    cell.baseFrame = baseFrame;
    cell.frame = cellFrame;
}

extern "C" void reloadPredictionBar() {
    if (isiOS10Up)
        return;
    UIKeyboardPredictionView *kbView = (UIKeyboardPredictionView *)[objc_getClass("UIKeyboardPredictionView") activeInstance];
    if ([kbView isKindOfClass:objc_getClass("UIKeyboardPredictionView")]) {
        if (!kbView.show)
            return;
        NSMutableArray *cells = MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells");
        if (cells && cells.count) {
            for (UIKeyboardPredictionCell *cell in cells)
                [cell removeFromSuperview];
            [cells release];
            NSUInteger cellCount = [objc_getClass("UIKeyboardPredictionView") numberOfCandidates];
            cells = [[NSMutableArray alloc] initWithCapacity:cellCount];
            if (cellCount > 0) {
                NSUInteger index = 0;
                do {
                    UIKeyboardPredictionCell *cell = [[objc_getClass("UIKeyboardPredictionCell") alloc] initWithFrame:CGRectZero];
                    cell.label.font = [UIFont systemFontOfSize:18.0];
                    cell.opaque = NO;
                    [kbView addSubview:cell];
                    setCellRect(cell, kbView.frame, index, cellCount);
                    [cells addObject:cell];
                    index++;
                } while (index < cellCount);
            }
            MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells") = cells;
        }
        [UIKeyboardImpl.activeInstance.autocorrectionController updateSuggestionViews];
    }
}

BOOL is_kbd;

static NSUInteger predictionCountForLandscape(BOOL landscape) {
    return landscape ? landscapeCount : portraitCount;
}

static NSUInteger predictionCount() {
    UIInterfaceOrientation orientation = [[UIKeyboard activeKeyboard] interfaceOrientation];
    if (orientation == 0)
        orientation = [UIApplication.sharedApplication _frontMostAppOrientation];
    BOOL isLandscape = orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight;
    return predictionCountForLandscape(isLandscape);
}

%group Apps

%hook UICompatibilityInputViewController

- (void)didRotateFromInterfaceOrientation: (NSInteger)orientation {
    %orig;
    if (landscapeCount != portraitCount)
        reloadPredictionBar();
}

%end

%hook UITextReplacementGeneratorForCorrections

- (void)setMaxCountAfterAutocorrectionGuesses: (NSUInteger)count {
    %orig(predictionCount());
}

- (NSUInteger)maxCountAfterAutocorrectionGuesses {
    return predictionCount();
}

- (void)setMaxCountAfterSpellingGuesses:(NSUInteger)count {
    %orig(predictionCount());
}

%end

BOOL padHook = NO;

%hook UIDevice

- (UIUserInterfaceIdiom)userInterfaceIdiom {
    return padHook ? UIUserInterfaceIdiomPhone : %orig;
}

%end

%hook UIKeyboardPredictionView

+ (CGFloat)overlapHeight {
    return predictionGap;
}

+ (CGFloat)predictionViewHeightForState:(NSInteger)state orientation:(NSInteger)orientation {
    CGFloat height = %orig;
    return height > 0.0 ? height * barHeightFactor : height;
}

// iOS 9.0+
+ (CGFloat)predictionViewWidthForOrientation:(NSInteger)orientation {
    padHook = maxPad;
    CGFloat width = %orig;
    padHook = NO;
    return width;
}

+ (NSUInteger)numberOfCandidates {
    return unhook ? %orig : predictionCount();
}

- (id)initWithFrame:(CGRect)frame {
    padHook = !isiOS9Up;
    self = %orig;
    padHook = NO;
    return self;
}

- (NSUInteger)messageCount {
    return predictionCount();
}

- (NSUInteger)maxMessageCount {
    return predictionCount();
}

%end

%end

%group Apps_iOS10Up

%hook UIKeyboardPredictionView

- (void)initCells {
    if (MSHookIvar<NSMutableArray *>(self, "m_predictionCells") == nil) {
        NSUInteger count = MAX([NSClassFromString(@"UIKeyboardPredictionView") numberOfCandidates], 3);
        MSHookIvar<NSMutableArray *>(self, "m_threeTextCells") = [self createCells:count];
        MSHookIvar<NSMutableArray *>(self, "m_twoTextCells") = [self createCells:2];
        MSHookIvar<NSMutableArray *>(self, "m_oneTextCells") = [self createCells:3];
        MSHookIvar<NSMutableArray *>(self, "m_emojiCells") = [self createCells:count];
        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:count];
        MSHookIvar<NSMutableArray *>(self, "m_textAndEmojiCells") = array;
        [array addObjectsFromArray:[MSHookIvar<NSMutableArray *>(self, "m_threeTextCells") subarrayWithRange:NSMakeRange(0, count - 2)]];
        [MSHookIvar<NSMutableArray *>(self, "m_textAndEmojiCells") addObjectsFromArray:MSHookIvar < NSMutableArray *> (self, "m_emojiCells")];
        MSHookIvar<NSMutableArray *>(self, "m_lastCell") = [MSHookIvar<NSMutableArray *>(self, "m_threeTextCells")lastObject];
        MSHookIvar<NSMutableArray *>(self, "m_predictionCells") = MSHookIvar<NSMutableArray *>(self, "m_threeTextCells");
        [MSHookIvar<NSMutableArray *>(self, "m_threeTextCells") enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            [self addSubview:obj];
        }];
        MSHookIvar<NSUInteger>(self, "m_autocorrectionCell") = NSNotFound;
        int *token = &MSHookIvar<int>(self, "_notifyBatterySaverToken");
        int status = notify_register_dispatch("com.apple.system.batterysavermode", token, dispatch_get_main_queue(), ^(int token_) {
            uint64_t state = UINT64_MAX;
            notify_get_state(token_, &state);
            for (UIKeyboardPredictionCell *cell in MSHookIvar<NSMutableArray *>(self, "m_predictionCells")) {
                cell.label.enableAnimation = state != 0;
            }
        });
        if (status != NOTIFY_STATUS_OK)
            NSLog(@"Failed to register for battery saver notifications");
    }
}

- (void)_setPredictions:(id)predictions autocorrection:(id)autocorrection emojiList:(id)emojiList {
    unhook = YES;
    %orig;
    unhook = NO;
}

%end

%hook UIKeyboardImpl

- (id)replacementsFromSelectedText {
    unhook = YES;
    id orig = %orig;
    unhook = NO;
    return orig;
}

%end

%end

%group Apps_preiOS10

%hook UIKeyboardPredictionView

- (void)_setPredictions: (NSArray *)predictions autocorrection: (TIAutocorrectionList *)autocorrection {
    %orig;
    [self setCellsFrame:self.frame];
}

%new
- (void)setCellsFrame: (CGRect)frame {
    if (MSHookIvar<BOOL>(self, "m_isMinimized"))
        return;
    NSMutableArray *cells = MSHookIvar<NSMutableArray *>(self, "m_predictionCells");
    NSUInteger cellCount = cells.count;
    if (cellCount) {
        NSInteger state = self.state;
        if (state != 0) {
            NSUInteger index = 0;
            do {
                UIKeyboardPredictionCell *cell = cells[index];
                setCellRect(cell, frame, index, cellCount);
                index++;
            } while (index < cellCount);
        }
    }
}

- (void)setFrame:(CGRect)frame {
    padHook = !isiOS9Up;
    %orig;
    padHook = NO;
    [self setCellsFrame:frame];
}

%end

%end

%group kbd

BOOL fakeCount = NO;
BOOL markCode1 = NO;
BOOL markCode2 = YES;
int seeArrays = 0;
NSUInteger excess = 0;

%hook __NSPlaceholderArray

- (id)initWithCapacity: (NSUInteger)capacity {
    if (fakeCount && markCode1) {
        if (capacity == 2 || capacity == 3) {
            capacity = maxCount;
            seeArrays++;
        }
        if (seeArrays == 2)
            markCode1 = NO;
    }
    return %orig(capacity);
}

%end

%hook __NSArrayM

- (NSUInteger)count {
    NSUInteger count = %orig;
    if (fakeCount && markCode2) {
        if (count > 2 && excess++ <= maxCount - 3)
            return 2;
        excess = 0;
    }
    return count;
}

%end

%hook TIKeyboardInputManagerZephyr

- (id)autocorrection {
    if (fakeCount)
        markCode1 = YES;
    return %orig;
}

- (id)completionCandidates {
    if (fakeCount)
        markCode2 = NO;
    id r = %orig;
    if (fakeCount)
        markCode2 = YES;
    return r;
}

- (id)extendedAutocorrection:(id)arg1 spanningInputsForCandidates:(id)arg2 {
    markCode2 = NO;
    return %orig;
}

- (TIAutocorrectionList *)autocorrectionList {
    fakeCount = YES;
    TIAutocorrectionList *t1 = %orig;
    fakeCount = markCode1 = markCode2 = NO;
    return t1;
}

- (id)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count {
    return %orig(maxCount);
}

%end

%hook TICandidateCommitHistory

- (id)initWithMaxCommittedCandidateCount: (NSUInteger)count {
    return %orig(maxCount);
}

- (NSUInteger)maxCommittedCandidateCount {
    return maxCount;
}

- (void)setMaxCommittedCandidateCount:(NSUInteger)count {
    %orig(maxCount);
}

%end

%hook TIKeyboardInputManager

- (NSUInteger)maxCandidateCount {
    return maxCount;
}

- (void)setMaxCandidateCount:(NSUInteger)count {
    %orig(maxCount);
}

%end

%end

HaveCallback() {
    GetPrefs()
    GetBool2(maxPad, NO)
    GetInt2(landscapeCount, 3)
    GetInt2(portraitCount, 3)
    GetCGFloat2(predictionGap, 1.0)
    GetCGFloat2(barHeightFactor, 1.0)
    if (!is_kbd)
        reloadPredictionBar();
    updateMaxCount();
}

%ctor {
    if (_isTarget(TargetTypeGUINoExtension, @[ @"kbd" ])) {
        is_kbd = NSBundle.mainBundle.bundleIdentifier == nil;
        HaveObserver();
        callback();
        dlopen(realPath2(@"/System/Library/TextInput/libTextInputCore.dylib"), RTLD_LAZY);
        if (is_kbd) {
            %init(kbd);
        } else {
            %init(Apps);
            if (isiOS10Up) {
                %init(Apps_iOS10Up)
            } else {
                %init(Apps_preiOS10);
            }
        }
    }
}
