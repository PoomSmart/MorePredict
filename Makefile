DEBUG = 0

ifeq ($(SIMULATOR),1)
	TARGET = simulator:clang:latest:8.0
	ARCHS = x86_64 i386
else
	TARGET = iphone:latest:7.1
endif

PACKAGE_VERSION = 1.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MorePredict
MorePredict_FILES = Tweak.xm
MorePredict_USE_SUBSTRATE = 1

include $(THEOS_MAKE_PATH)/tweak.mk
include ../preferenceloader/locatesim.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R MorePredict $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MorePredict$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)

ifeq ($(SIMULATOR),1)
setup:: clean all
	$(ECHO_NOTHING)find $(PWD)/Resources -name .DS_Store | xargs rm -rf$(ECHO_END)
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
	@sudo cp -vR $(PWD)/MorePredict $(PL_SIMULATOR_PLISTS_PATH)/

remove::
	@[ ! -d $(PL_SIMULATOR_PLISTS_PATH)/MorePredict ] || sudo rm -rf $(PL_SIMULATOR_PLISTS_PATH)/MorePredict
	@rm -f /opt/simject/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).plist
endif
