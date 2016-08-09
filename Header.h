#import "../PS.h"

@interface UIInputSwitcherView : UIView
+ (UIInputSwitcherView *)activeInstance;
- (void)toggleKeyboardPredictionPreference;
@end

@interface UIKeyboardAssistantBar : NSObject
+ (CGFloat)assistantBarHeight;
@end

@interface UIMorphingLabel : UILabel
@end

@interface UIKeyboardPredictionCell : UIView
@property CGRect collapsedFrame;
@property CGRect activeFrame;
@property CGRect baseFrame;
@property(retain, nonatomic, readonly) UIMorphingLabel *label;
@end

@interface UIKeyboardPredictionView : UIView
@property NSInteger state;
@property BOOL show;
+ (NSUInteger)numberOfCandidates;
+ (CGFloat)predictionViewHeightForState:(NSInteger)state orientation:(UIInterfaceOrientation)orientation;
+ (CGFloat)overlapHeight;
- (void)setPredictionViewState:(NSInteger)state animate:(BOOL)animate notify:(BOOL)notify;
- (void)setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection;
- (void)_setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection;

- (void)setCellsFrame:(CGRect)frame;
@end

@interface TIInputMode : NSObject {
	uint8_t NSObject_opaque[4];
	NSString *_languageWithRegion;
	NSString *_variant;
	NSLocale *_locale;
	Class _inputManagerClass;
	NSString *_normalizedIdentifier;
}
@end

@interface TIKeyboardInputManagerBase : NSObject {
	TIInputMode *_inputMode;
}
@end

@interface TIKeyboardInputManager : TIKeyboardInputManagerBase
@end

typedef struct TIInputManagerZephyr {
	TIKeyboardInputManager *manager;
} *TIInputManagerZephyrRef;

@interface TIKeyboardInputManagerZephyr : TIKeyboardInputManager {
	TIInputManagerZephyrRef m_impl;
	NSMutableString *m_composedText;
	unsigned int m_initialSelectedIndex;
	int m_typology_recorder;
	char _isEditingWordPrefix;
	char _wordLearningEnabled;
	int _config;
	int _autocorrectionHistory;
	int _rejectedAutocorrections;
	int _autocorrectionsSuggestedForCurrentInput;
	int _textCheckerExemptions;
	int _acceptableCharacterSet;
	int _revisionHistory;
	int _autoshiftRegexLoader;
}
- (NSArray *)completionCandidates;
- (NSIndexSet *)indexesOfDuplicatesInCandidates:(NSArray *)candidates;
- (TIZephyrCandidate *)topCandidate;
- (TIZephyrCandidate *)extendedAutocorrection:(TIZephyrCandidate *)autocorrection spanningInputsForCandidates:(NSArray *)candidates;
- (TIAutocorrectionList *)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count;
- (TIAutocorrectionList *)autocorrectionListForSelectedText;
- (BOOL)shouldGenerateSuggestionsForSelectedText;
- (NSUInteger)inputCount;
@end