DEBUG = 0
PACKAGE_VERSION = 1.2

include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MorePredict
MorePredict_FILES = Tweak.xm
MorePredict_FRAMEWORKS = CoreGraphics UIKit
MorePredict_PRIVATE_FRAMEWORKS = TextInput

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R Resources $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MorePredict$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)