DEBUG = 0

ifeq ($(SIMULATOR),1)
	TARGET = simulator:clang:latest
	ARCHS = x86_64 i386
else
	TARGET = iphone:latest
endif

PACKAGE_VERSION = 1.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MorePredict
MorePredict_FILES = Tweak.xm
MorePredict_PRIVATE_FRAMEWORKS = TextInput
MorePredict_USE_SUBSTRATE = 1

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R Resources $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MorePredict$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)
	
all::
ifeq ($(SIMULATOR),1)
	@cp -v $(PWD)/.theos/$(THEOS_OBJ_DIR_NAME)/*.dylib /opt/simject
	@cp -v $(PWD)/*.plist /opt/simject
endif