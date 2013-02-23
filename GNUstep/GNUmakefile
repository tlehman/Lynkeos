include $(GNUSTEP_MAKEFILES)/common.make

# Change this to your special installation of FFmeg library
#ADDITIONAL_INCLUDE_DIRS += -I/usr/local/lib/

APP_NAME = Lynkeos

#Lynkeos_RESOURCE_DIRS = ../GNUstep
Lynkeos_RESOURCE_DIRS = $(PWD)

Lynkeos_OBJC_FILES = corelation.m \
FFmpegReader.m \
LynkeosBasicAlignResult.m \
LynkeosColumnDescriptor.m \
LynkeosFourierBuffer.m \
LynkeosGammaCorrecter.m \
LynkeosImageProcessingParameter.m \
LynkeosLogFields.m \
LynkeosObjectCache.m \
LynkeosProcessableImage.m \
LynkeosProcessingDefs.m \
LynkeosProcessingParameterMgr.m \
LynkeosStandardImageBuffer.m \
main.m \
MyAboutWindowController.m \
MyCachePrefs.m \
MyCalibrationLock.m \
MyChromaticAlignerView.m \
MyChromaticLevels.m \
MyCocoaFilesReader.m \
MyCustomAlert.m \
MyCustomViews.m \
MyDeconvolution.m \
MyDeconvolutionView.m \
MyDocumentData.m \
MyDocument.m \
MyGeneralPrefs.m \
MyImageAligner.m \
MyImageAlignerPrefs.m \
MyImageAlignerView.m \
MyImageAnalyzer.m \
MyImageAnalyzerPrefs.m \
MyImageAnalyzerView.m \
MyImageListEnumerator.m \
MyImageListItem.m \
MyImageList.m \
MyImageListWindow.m \
MyImageListWindowOutlineView.m \
MyImageListWindowSplitView.m \
MyImageListWindowToolbar.m \
MyImageStacker.m \
MyImageStackerPrefs.m \
MyImageStackerView.m \
MyImageView.m \
MyImageViewSelection.m \
MyListManagement.m \
MyLucyRichardson.m \
MyLucyRichardsonView.m \
MyPluginsController.m \
MyProcessingThread.m \
MyProcessStackView.m \
MyTiff16Reader.m \
MyTiffWriter.m \
MyUnsharpMask.m \
MyUnsharpMaskView.m \
MyUserPrefsController.m \
MyWavelet.m \
MyWaveletView.m \
ProcessStackManager.m \
LynkeosThreadConnection.m \
SMDoubleSliderCell.m \
SMDoubleSlider.m

Lynkeos_C_FILES = ProcessingUtilities.c

Lynkeos_MAIN_MODEL_FILE=MainMenu.gorm
Lynkeos_RESOURCE_FILES= $(Lynkeos_RESOURCE_DIRS)/MainMenu.gorm \
$(Lynkeos_RESOURCE_DIRS)/ImageListWindow.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyDeconvolution.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyImageAligner.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyImageAnalyzer.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyImageStacker.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyLucyRichardson.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyProcessStackView.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyUnsharpMask.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyWavelet.gorm \
$(Lynkeos_RESOURCE_DIRS)/TiffWriter.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyChromaticAlign.gorm \
$(Lynkeos_RESOURCE_DIRS)/MyChromaticLevels.gorm

ADDITIONAL_OBJC_LIBS += -lavcodec -lavformat -lavutil -lfftw3f_threads -lfftw3f -lm
#ADDITIONAL_LIB_DIRS += 

ADDITIONAL_OBJCFLAGS += -std=gnu99
ADDITIONAL_CPPFLAGS += -I$(PWD)/../Sources \
-I$(PWD)/../ThreadConnectionSources \
-I$(PWD)/../ThirdPartySources/SMDoubleSlider

include $(GNUSTEP_MAKEFILES)/application.make
#include $(GNUSTEP_MAKEFILES)/ctool.make
#include $(GNUSTEP_MAKEFILES)/objc.make
#include $(GNUSTEP_MAKEFILES)/bundle.make

VPATH +=:$(PWD)/../Sources\
:$(PWD)/../ThreadConnectionSources\
:$(PWD)/../ThirdPartySources/SMDoubleSlider

