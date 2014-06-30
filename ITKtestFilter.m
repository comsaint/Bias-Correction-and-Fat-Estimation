//
//  ITKtestFilter.m
//  ITKtest
//
//  Copyright (c) 2014 Long. All rights reserved.
//

#import "ITKtestFilter.h"
#import "MainNibWindowController.h"

#import "math.h"

#define id Id
#include "itkImage.h"
#include "itkImportImageFilter.h"
#include "itkN4BiasFieldCorrectionImageFilter.h"
#include "itkOtsuThresholdImageFilter.h"
#include "itkArray.h"
#include "itkShrinkImageFilter.h"
#include "itkExtractImageFilter.h"
#undef id

#define ImageDimension 3

@implementation ITKtestFilter
/*
- (void) initPlugin
{
}
*/
- (ViewerController*) viewerController
{
    return viewerController;
}

- (long) filterImage:(NSString*) menuName
{
    MainNibWindowController* coWin = [[MainNibWindowController alloc] init:self];
    [coWin showWindow:self];
    return 0;
}

- (void) biascorrect:(ITKtestFilter *)filter
{
    typedef     float itkPixelType;
    typedef     itk::Image< itkPixelType, ImageDimension > ImageType;
    typedef     itk::ImportImageFilter< itkPixelType, ImageDimension > ImportFilterType;
    typedef typename ImageType::Pointer ImagePointer;
    
    
    DCMPix      *firstPix = [[viewerController pixList] objectAtIndex:0];
    int         slices = [[viewerController pixList] count];
    long        bufferSize;
    
    ImportFilterType::Pointer       importFilter = ImportFilterType::New();
    ImportFilterType::SizeType      size;
    ImportFilterType::IndexType     start;
    ImportFilterType::RegionType    region;
    
    start.Fill(0);
    
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    
    bufferSize = size[0] * size[1] * size[2];
    
    double  origin[3];
    double  originConverted[ 3];
    double  vectorOriginal[ 9];
    double  voxelSpacing[3];
    
    origin[0] = [firstPix originX];
    origin[1] = [firstPix originY];
    origin[2] = [firstPix originZ];
    
    [firstPix orientationDouble: vectorOriginal];
    originConverted[ 0] = origin[ 0] * vectorOriginal[ 0] + origin[ 1] * vectorOriginal[ 1] + origin[ 2] * vectorOriginal[ 2];
    originConverted[ 1] = origin[ 0] * vectorOriginal[ 3] + origin[ 1] * vectorOriginal[ 4] + origin[ 2] * vectorOriginal[ 5];
    originConverted[ 2] = origin[ 0] * vectorOriginal[ 6] + origin[ 1] * vectorOriginal[ 7] + origin[ 2] * vectorOriginal[ 8];
    
    voxelSpacing[0] = [firstPix pixelSpacingX];
    voxelSpacing[1] = [firstPix pixelSpacingY];
    voxelSpacing[2] = [firstPix sliceInterval];
    
    region.SetIndex(start);
    region.SetSize(size);
    
    importFilter->SetRegion(region);
    importFilter->SetOrigin(originConverted);
    importFilter->SetSpacing(voxelSpacing);
    importFilter->SetImportPointer([viewerController volumePtr] , bufferSize, false);
    ImagePointer inputImage = importFilter->GetOutput();
    //The image is now imported to ITK as inputImage.
    
    /*
     N4BiasCorrection - workflow:
     1. Create a mask.
     2. Shrink the inputImage (as well as mask) down to reduce computation time (significantly).
     3. Run bias correction.
     4. Recover the bias field after bias correction.
     5. Divide inputImage by the bias field to get the output image.
     6. Make the size of output image identical to inputImage (otherwise Osirix will crash!)
     */
    
    
    //1. Create Otsu mask
    typedef itk::Image<unsigned char, ImageDimension> MaskImageType;
    typedef typename MaskImageType::Pointer MaskImagePointer;
    
    typedef itk::OtsuThresholdImageFilter<ImageType,MaskImageType> ThresholdType;
    typename ThresholdType::Pointer otsu = ThresholdType::New();
    typename MaskImageType::Pointer maskImage = NULL;
    typename ImageType::Pointer outImage = NULL;
    
    otsu->SetInput(importFilter->GetOutput());
    otsu->SetNumberOfHistogramBins(200);
    otsu->SetInsideValue(0);
    otsu->SetOutsideValue(1);
    otsu->Update();
    maskImage = otsu->GetOutput();
    maskImage->DisconnectPipeline();
    //Done with mask creation
    
    
    
    
    //Instantiate and Set some parameters for biascorrectionFilter
    typedef itk::N4BiasFieldCorrectionImageFilter<ImageType, MaskImageType, ImageType> N4BiasFieldCorrectionImageFilterType;
    N4BiasFieldCorrectionImageFilterType::Pointer biascorrectionFilter = N4BiasFieldCorrectionImageFilterType::New();
    
    //These parameters can be changed:
    unsigned int iterlevel = 3;
    biascorrectionFilter->SetNumberOfFittingLevels(iterlevel);
    N4BiasFieldCorrectionImageFilterType::VariableSizeArrayType maxiterary(iterlevel);
    //Remember to change these as well
    maxiterary[0]=100;
    maxiterary[1]=50;
    maxiterary[2]=50;
    
    biascorrectionFilter->SetMaximumNumberOfIterations(maxiterary);
    biascorrectionFilter->SetConvergenceThreshold(0.0001);
    biascorrectionFilter->SetMaskLabel(1);//Make sure this is the same as specified in the mask
    biascorrectionFilter->SetBiasFieldFullWidthAtHalfMaximum(0.15);
    biascorrectionFilter->SetSplineOrder(3);
    biascorrectionFilter->SetWienerFilterNoise(0.01);
    //End of parameters
    
    
    
    //2. Shrink (original) image to decrease computation time
    unsigned int shrink_factor = 4;//This can be changed
    
    typedef itk::ShrinkImageFilter<ImageType, ImageType> ShrinkImageFilterType;
    typename ShrinkImageFilterType::Pointer shrinker =ShrinkImageFilterType::New();
    shrinker->SetInput(inputImage);
    shrinker->SetShrinkFactors(shrink_factor);
    
    
    //Shrink (mask) image as well
    typedef itk::ShrinkImageFilter<MaskImageType, MaskImageType> MaskShrinkImageFilterType;
    typename MaskShrinkImageFilterType::Pointer maskshrinker = MaskShrinkImageFilterType::New();
    maskshrinker->SetInput(maskImage);
    maskshrinker->SetShrinkFactors(shrink_factor);
    
    
    //Execute shrinking
    shrinker->Update();
    maskshrinker->Update();
    
    ImagePointer shrinkinputImage = shrinker->GetOutput();
    MaskImagePointer shrinkmaskImage = maskshrinker->GetOutput();
    
    
    
    
    //3. Set inputs of the biascorrectionFilter, and execute
    biascorrectionFilter->SetInput(shrinkinputImage);
    biascorrectionFilter->SetMaskImage(shrinkmaskImage);
    biascorrectionFilter->Update();
    
    
    //4. Recover the bias field
    /**
     * Reconsruct the bias field at full image resoluion.  Divide
     * the original input image by the bias field to get the final
     * corrected image.
     * This part was taken from
     */
    typedef itk::BSplineControlPointImageFilter<N4BiasFieldCorrectionImageFilterType::BiasFieldControlPointLatticeType,N4BiasFieldCorrectionImageFilterType::ScalarImageType> BSplinerType;
    BSplinerType::Pointer bspliner = BSplinerType::New();
    
    ImageType::IndexType inputImageIndex =
    inputImage->GetLargestPossibleRegion().GetIndex();
    ImageType::SizeType inputImageSize =
    inputImage->GetLargestPossibleRegion().GetSize();
    
    ImageType::PointType newOrigin = inputImage->GetOrigin();
    bspliner->SetInput( biascorrectionFilter->GetLogBiasFieldControlPointLattice() );
    bspliner->SetSplineOrder( biascorrectionFilter->GetSplineOrder() );
    bspliner->SetSize( inputImage->GetLargestPossibleRegion().GetSize() );
    bspliner->SetOrigin( newOrigin );
    bspliner->SetDirection( inputImage->GetDirection() );
    bspliner->SetSpacing( inputImage->GetSpacing() );
    bspliner->Update();
    
    ImageType::Pointer logField = ImageType::New();
    logField->SetOrigin( inputImage->GetOrigin() );
    logField->SetSpacing( inputImage->GetSpacing() );
    logField->SetRegions( inputImage->GetLargestPossibleRegion() );
    logField->SetDirection( inputImage->GetDirection() );
    logField->Allocate();
    
    itk::ImageRegionIterator<N4BiasFieldCorrectionImageFilterType::ScalarImageType> IB(
                                                                                       bspliner->GetOutput(),
                                                                                       bspliner->GetOutput()->GetLargestPossibleRegion() );
    itk::ImageRegionIterator<ImageType> IF( logField,
                                           logField->GetLargestPossibleRegion() );
    for( IB.GoToBegin(), IF.GoToBegin(); !IB.IsAtEnd(); ++IB, ++IF )
    {
        IF.Set( IB.Get()[0] );
    }
    
    
    //Exponential
    typedef itk::ExpImageFilter<ImageType, ImageType> ExpFilterType;
    ExpFilterType::Pointer expFilter = ExpFilterType::New();
    expFilter->SetInput( logField );
    expFilter->Update();
    
    
    
    //5. Get the output image by dividing inputInage by bias field
    typedef itk::DivideImageFilter<ImageType, ImageType, ImageType> DividerType;
    DividerType::Pointer divider = DividerType::New();
    divider->SetInput1( inputImage );
    divider->SetInput2( expFilter->GetOutput() );
    divider->Update();
    
    
    
    //6. Adjust output image size by cropper
    //Crop the image
    ImageType::RegionType inputRegion;
    inputRegion.SetIndex( inputImageIndex );
    inputRegion.SetSize( inputImageSize );
    typedef itk::ExtractImageFilter<ImageType, ImageType> CropperType;
    CropperType::Pointer cropper = CropperType::New();
    cropper->SetInput( divider->GetOutput() );
    cropper->SetExtractionRegion( inputRegion );
    cropper->SetDirectionCollapseToSubmatrix();
    cropper->Update();
    
    //Output
    float* resultBuff = cropper->GetOutput()->GetBufferPointer();
    
    
    long mem = bufferSize * sizeof(float);
    memcpy( [viewerController volumePtr], resultBuff, mem);
    
    [viewerController needsDisplayUpdate];
}

-(void) Setpix:(DCMPix *)pix_in
{
    pix = pix_in;
}

-(float) getSkewness
{
    return skewness;
}

- (float) calculateRating:(ROI*)curROI
{
    int num_bin = 255;
    
    long count=0;
    float min=0,max=0;
    
    float** loc=nil;
    
    float *values = [pix getROIValue: &count :curROI :loc];
    
    [pix computeROI:curROI
                   :nil     //mean
                   :nil     //total sum, not necessary
                   :nil     //dev
                   :&min
                   :&max
     ];
     
    
    //the easiest way to normalize is to standardise the ROI to [0,1]

    
    //linear scaling
    for (int i = 0;i<count;i++){
        values[i] = (values[i]-min)/(max-min);
    }
    
    //calculate mean
    float mean = 0.0;
    for (int i = 0;i<count;i++){
        mean += values[i];
    }
    mean/=count;
    
    //calculate variance
    float m2 = 0.0;//second moent, i.e. variance
    for (int i =0;i<count;i++)
    {
        m2 += powf((values[i]-mean), 2);
    }
    m2/=count;
    
    //claculate skewness
    float m3 = 0.0;//second and thrid moments
    
    skewness=0.0;
    for (int i =0;i<count;i++)
    {
        m3 += powf((values[i]-mean), 3);
    }
    m3 /= count;
    
    skewness = m3/powf(m2, 1.5);
    
    
    //Put values into histogram bins
    double *myhistogram = (double*)calloc(num_bin, sizeof(double));
    //Initialize: just in case...
    for (int i =0;i<num_bin;i++){
        myhistogram[i]=0;
    }
    
    //Put values into bins
    for (int i=0;i<count;i++){
        for (int j=0;j<num_bin;j++){
            if (values[i]>=j && values[i]<j+1) {
                myhistogram[j]=myhistogram[j]+1;
                //break;
            }
        }//can be rewritten into a while loop
    }
    //Moto of engineering: if it is not broken, don't fix it.
    
    // normalize the histogram to probability [0 1]
    for (int i=0;i<num_bin;i++){
        myhistogram[i]=(double) myhistogram[i]/count;
    }
    
    //Hereforth compute rating with whatever method(s)
    
    //1. Simple skewness
    // Higher skewness -> lower rating
    const unsigned int rating_levels = 5;//how many levels do we have?
    float skew_list[rating_levels] = {3.6,3.2,2.4,2.1,1.7};//put threshold values here
    float rating = 0.0;//default = 0 ("Not Rated")
    
    if (skewness>skew_list[0])
    {rating = 1.0;}
    else if (skewness>skew_list[1])
    {rating = 2.0;}
    else if (skewness>skew_list[2])
    {rating = 2.5;}
    else if (skewness>skew_list[3])
    {rating = 3.0;}
    else if (skewness>skew_list[4])
    {rating = 3.5;}
    else if (skewness<skew_list[4])
    {rating = 4.0;}
    
    //End rating computation

    
    return rating;
}
@end