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
#define NumOfCases 10

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
    //also store the max and min values of the slice
    float *fImageA=[pix fImage];
    int x = [pix pheight]*[pix pwidth];
    float v_min=fImageA[0],v_max=fImageA[0];
    while (x-- >0) {
        if (fImageA[x]<v_min){v_min=fImageA[x];}
        if (fImageA[x]>v_max){v_max=fImageA[x];}
    }
    pix_max=v_max;
    pix_min=v_min;
}

-(float) getSkewness
{
    return skewness;
}

- (float) calculateRating:(ROI*)curROI
{
    const int num_bin = 100;
    
    long count=0;
    float min=0,max=0;
    
    float** loc=nil;
    
    float *values = [pix getROIValue: &count :curROI :loc];
    /*
    [pix computeROI:curROI
                   :nil     //mean
                   :nil     //total sum, not necessary
                   :nil     //dev
                   :&min
                   :&max
     ];
    */
    
    //use global max and min as scaling factors
    min=pix_min;
    max=pix_max;
    
    //the easiest way to normalize is to standardise the whole image to [0,1]
    
    //linear scaling
    for (int i = 0;i<count;i++){
        values[i] = (values[i]-min)/(max-min);
    }
    
    /*
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
    */
    
    //Put values into histogram bins
    float *myhistogram = (float*)calloc(num_bin, sizeof(float));
    //float myhistogram[num_bin];
    
    //Initialize: just in case...
    for (int i =0;i<num_bin;i++){
        myhistogram[i]=0;
    }
    
    //Put values into bins
    float bin_width = (float) 1.0/num_bin;
    for (int i=0;i<count;i++)
    {
        for (int j=0;j<num_bin;j++)
        {
            if (values[i]>=j*bin_width && values[i]<(j+1)*bin_width)
            {
                myhistogram[j]++;
                //break;
            }
        }//can be rewritten into a while loop
    }
    //Moto of engineering: if it is not broken, don't fix it.
    
    // normalize the histogram to probability [0 1]
    float hist_cksum=0.0;
    for (int i=0;i<num_bin;i++){
        myhistogram[i]=(float) myhistogram[i]/count;
        hist_cksum+=myhistogram[i];
    }
    
    float rating = 0.0;//default = 0 ("Not Rated")
    
    //////////////////////////////////////////////////
    //
    //Hereforth compute rating with whatever method(s)
    //
    //////////////////////////////////////////////////
    
    //1. Simple skewness
    // Higher skewness -> lower rating
    /*
    const unsigned int rating_levels = 5;//how many levels do we have?
    float skew_list[rating_levels] = {3.6,3.2,2.4,2.1,1.7};//put threshold values here
    
    
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
    */
    //End rating computation #1
    
    
    //2. L2 distance
    /*
    // Read the comparison csv file 'mtx_export.csv'
    NSString* filename = @"mtx_export.csv";
    NSString* contents = [NSString stringWithContentsOfFile:filename encoding:(NSUTF8StringEncoding) error:nil];
    //NSMutableArray *csvArray = [[NSMutableArray alloc] init];
    //csvArray = [[contents componentsSeparatedByString:@"\n"] mutableCopy];
    //NSString *keyString = [csvArray objectAtIndex:0];
    
    
    NSArray* lines = [contents componentsSeparatedByString:@"\n"];
    
    int img_count = [lines count];
    double ratingArray[img_count];
    double hist_dist[img_count][num_bin];
    
    int tmp_cnt=0;
    for (NSString* line in lines)
    {
        NSArray* fields = [line componentsSeparatedByString:@","];
        //ratingArray[tmp_cnt]=[[fields objectAtIndex:0] doubleValue];
        //for (int i=1;i<=num_bin;i++)
        //{
        //    hist_dist[tmp_cnt][i-1]=[[fields objectAtIndexedSubscript:i] doubleValue];
        //}
        
        //tmp_cnt++;
    }
    
    for (int i=0;i<img_count;i++)
    {
        ratingArray[i]=[[lines objectAtIndex:i] intValue];
    }
    
    //testing
    rating = img_count;
    */
    
    //Manually define ratings and histogram
    const float fat_rating[NumOfCases]={3,2,3,3,2,4,3,4,4,3};
    //const float fat_rating[NumOfCases]={1,2,3,4,5,6,7,8,9,10};
    const float fat_hist[NumOfCases][num_bin]={
        {0,0.00015679,0.00094073,0.0018815,0.008937,0.027752,0.066479,0.10426,0.12041,0.099404,0.08592,0.063656,0.055033,0.035121,0.034337,0.023989,0.0254,0.014425,0.02101,0.014895,0.015052,0.0097209,0.011602,0.0097209,0.0086234,0.0062716,0.0064283,0.0095641,0.0054876,0.0048605,0.0070555,0.0050172,0.0048605,0.0056444,0.0042333,0.0058012,0.0040765,0.0053308,0.0031358,0.0053308,0.0023518,0.002195,0.0039197,0.0031358,0.0017247,0.00094073,0.0020383,0.0028222,0.0025086,0.0047037,0.002195,0.00062716,0.00078394,0.0026654,0.00078394,0.0017247,0.00094073,0.0012543,0.0010975,0.002195,0.002195,0.0017247,0.0015679,0.0010975,0.0010975,0.00078394,0.00062716,0.0014111,0,0.0014111,0.00062716,0.00062716,0.0010975,0.00062716,0,0.00031358,0.00062716,0.0010975,0.00062716,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0.00068766,0.0042635,0.018842,0.051437,0.10796,0.15706,0.18526,0.15376,0.10741,0.061615,0.038234,0.027094,0.011553,0.012378,0.011415,0.0079769,0.0057764,0.0031633,0.0034383,0.0038509,0.0035758,0.0023381,0.0023381,0.0024756,0.0015129,0.0016504,0.0015129,0.00055013,0.0012378,0.0022005,0.00027507,0.00027507,0.00055013,0.00096273,0.00027507,0,0.0004126,0.00055013,0,0,0.0008252,0.00027507,0.00027507,0.00027507,0,0.00027507,0.00027507,0.0004126,0,0.00013753,0,0,0.00027507,0.00013753,0.00013753,0,0.00013753,0.0004126,0,0.00027507,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0.00053792,0.0064551,0.011431,0.039537,0.058903,0.10422,0.12305,0.12278,0.1014,0.071678,0.054465,0.038999,0.027434,0.022324,0.025955,0.018693,0.011834,0.012372,0.013583,0.011296,0.0092792,0.0077999,0.0044379,0.0057827,0.0053792,0.0059172,0.0052448,0.003631,0.0044379,0.0029586,0.0030931,0.0032275,0.0025551,0.0018827,0.0022862,0.0034965,0.0025551,0.003631,0.0021517,0.0018827,0.0012103,0.0016138,0.0021517,0.0013448,0.0017483,0.00053792,0.0006724,0.0014793,0.0018827,0.0013448,0.0030931,0.0012103,0.00080689,0.0010758,0.00026896,0.0006724,0.0012103,0.0018827,0.0010758,0.0016138,0.00094137,0.0010758,0.0014793,0.0013448,0.0006724,0.0012103,0.0012103,0.0006724,0.00094137,0.0010758,0.00080689,0.00080689,0.00053792,0,0.00053792,0.00013448,0.00026896,0,0,0,0.00013448,0.00013448,0.00013448,0.00013448,0.00026896,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0.002088,0.002088,0.001044,0.0041761,0.017574,0.049765,0.082478,0.13189,0.14147,0.10092,0.08039,0.061945,0.045763,0.037411,0.038107,0.019662,0.019836,0.012876,0.010614,0.0093962,0.0085262,0.0087002,0.0074822,0.0090482,0.0043501,0.0064381,0.0076562,0.0048721,0.0046981,0.0029581,0.0055681,0.0040021,0.002088,0.0057421,0.0036541,0.0040021,0.001914,0.0055681,0.0024361,0.001914,0.002262,0.00052201,0.0033061,0.001044,0.001044,0.001566,0.00052201,0.0036541,0.00034801,0.001392,0.00069602,0.00069602,0.00087002,0.00052201,0.00034801,0.000174,0.001044,0.00034801,0.00052201,0.001044,0.000174,0.00087002,0.00069602,0.001044,0.00034801,0.00052201,0,0.00052201,0.000174,0,0.00034801,0,0,0,0,0.00034801,0.00052201,0.00034801,0,0,0.00069602,0.000174,0,0.000174,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0,0,0.0028571,0.025195,0.065974,0.11662,0.17584,0.17455,0.11377,0.078182,0.055065,0.036364,0.022338,0.013247,0.015584,0.011688,0.0080519,0.0075325,0.0077922,0.0033766,0.0018182,0.0018182,0.0020779,0.0028571,0.001039,0.0012987,0.0020779,0.00025974,0.0015584,0.0015584,0.0018182,0.001039,0.00077922,0.001039,0.00051948,0,0.00077922,0.0023377,0.00025974,0.00077922,0.00025974,0.00077922,0.001039,0.0025974,0.001039,0.0012987,0.0012987,0.0018182,0.00077922,0.00025974,0.0012987,0.00025974,0.00051948,0.00051948,0.0012987,0.0018182,0.0020779,0.0012987,0.0023377,0.00025974,0.0018182,0.0025974,0,0.0015584,0.00051948,0.001039,0.0015584,0.00051948,0.00051948,0.0012987,0.0036364,0,0.0012987,0.001039,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0,0.00036023,0.0010807,0.0028818,0.010807,0.025036,0.038905,0.06268,0.074027,0.086996,0.076189,0.074748,0.054935,0.050072,0.044488,0.036383,0.03062,0.029899,0.019452,0.016571,0.019272,0.017291,0.013329,0.013689,0.010627,0.011707,0.010807,0.0086455,0.010447,0.0084654,0.007745,0.0095461,0.0064841,0.0050432,0.0043228,0.0036023,0.0027017,0.0059438,0.0039625,0.003062,0.0039625,0.0050432,0.0041427,0.001621,0.0021614,0.0041427,0.003062,0.0023415,0.0028818,0.0034222,0.0025216,0.0027017,0.0034222,0.001621,0.0027017,0.0018012,0.0027017,0.0019813,0.0018012,0.0012608,0.0021614,0.0010807,0.0019813,0.0014409,0.0014409,0.00054035,0.0014409,0.0023415,0.0010807,0.0012608,0.0027017,0.0034222,0.001621,0.0019813,0.00090058,0.0021614,0.0014409,0.0012608,0.00036023,0.00072046,0.00018012,0,0.00036023,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0.00053291,0.0018652,0.005862,0.023981,0.045297,0.073275,0.10818,0.09619,0.095657,0.069544,0.048228,0.040234,0.051159,0.036771,0.027445,0.030909,0.023714,0.014655,0.019451,0.010658,0.017319,0.0085265,0.013323,0.0079936,0.0077272,0.0061284,0.0053291,0.0082601,0.0039968,0.0066613,0.0066613,0.0093259,0.0023981,0.0042633,0.0047962,0.0021316,0.0037303,0.0053291,0.0021316,0.0023981,0.00079936,0.0021316,0.0015987,0.0021316,0.0031974,0.002931,0.0013323,0.00026645,0.0018652,0.00079936,0.0010658,0.0018652,0.0026645,0.0018652,0,0.00079936,0.0010658,0.0013323,0.00053291,0.0010658,0.0026645,0.0018652,0.0013323,0.0010658,0.0015987,0.0013323,0.0013323,0.0010658,0.00079936,0,0.0018652,0,0.0018652,0.00079936,0.0010658,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0.00015065,0.00015065,0.00075324,0.0019584,0.0073817,0.010545,0.020187,0.034197,0.065532,0.064327,0.076378,0.073817,0.067038,0.05589,0.049262,0.03947,0.040976,0.027267,0.022748,0.021241,0.020187,0.01386,0.015818,0.016119,0.013558,0.015517,0.015969,0.010093,0.0087376,0.0093402,0.007683,0.0067792,0.008135,0.0075324,0.0085869,0.0078337,0.007683,0.0061766,0.0079843,0.0057246,0.0042181,0.0034649,0.0082856,0.0022597,0.0039168,0.0048207,0.0037662,0.0037662,0.005122,0.0067792,0.0027117,0.0018078,0.003013,0.0024104,0.0019584,0.0031636,0.0028623,0.0027117,0.0057246,0.003013,0.0034649,0.0022597,0.0057246,0.0036155,0.0048207,0.0040675,0.0019584,0.0018078,0.00090389,0.00060259,0.0003013,0.00075324,0.00045194,0,0,0.00090389,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0.00063776,0.0021259,0.005102,0.026573,0.04443,0.061437,0.082483,0.077381,0.06165,0.059524,0.05017,0.043155,0.027211,0.019345,0.019133,0.01977,0.013818,0.015731,0.015731,0.017219,0.017645,0.012117,0.01318,0.010842,0.0085034,0.011267,0.0085034,0.0099915,0.011905,0.011267,0.011692,0.0085034,0.0089286,0.016156,0.014031,0.0095663,0.0095663,0.0057398,0.010629,0.0042517,0.0053146,0.0089286,0.0085034,0.0093537,0.0085034,0.0097789,0.014456,0.0085034,0.01148,0.0080782,0.006165,0.0029762,0.005102,0.0021259,0.0021259,0.0012755,0.0021259,0.00063776,0.0023384,0.00042517,0.00021259,0.00085034,0.00042517,0.00063776,0.00085034,0.00063776,0.00021259,0.0010629,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0.0032186,0.013122,0.024263,0.063877,0.083684,0.081456,0.1129,0.12528,0.099282,0.063877,0.061154,0.037138,0.034167,0.023768,0.02253,0.026739,0.017331,0.010894,0.0066848,0.0094083,0.0086655,0.0076752,0.0079228,0.0047041,0.0049517,0.0019807,0.004209,0.002971,0.0037138,0.0024759,0.0061897,0.0027234,0.0014855,0.0022283,0.0014855,0.002971,0.00099034,0.00099034,0.0024759,0.00049517,0,0.00049517,0.0019807,0.00074276,0.00049517,0.0014855,0,0.00049517,0.00074276,0,0.00049517,0,0.00024759,0,0,0.00074276,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    };
    
    //Compute L2 distance
    float dist[NumOfCases];
    for (int i=0;i<NumOfCases;i++)
    {
        dist[i]=0.0;
        for (int j=0;j<num_bin;j++)
        {
            dist[i]+=powf(myhistogram[j]-fat_hist[i][j],2);
        }
    }
    
    
    //Compare distances - NN or kNN classifier
    /*
    mypair dist_rate_pair[NumOfCases];
    //Pair up dist and rating
    for (int i=0;i<NumOfCases;i++)
    {
        //mypair.insert(make_pair(dist[i],fat_rating[i]));
        dist_rate_pair[i].first=dist[i];
        dist_rate_pair[i].second=fat_rating[i];
    }
    */
    //silly bubble sort
    rating = fat_rating[0];
    float tmp_dist = dist[0];
    for(int i=1;i<NumOfCases;i++)
    {
        if (tmp_dist>dist[i]) {
            tmp_dist=dist[i];
            rating = fat_rating[i];
        }
    }
    //testing
    skewness = hist_cksum;
    
    //NSArray *dispArray = [NSString stringWithFormat:@"%f", pix_max];
    NSRunInformationalAlertPanel(@"Yeah",
                                 [NSString stringWithFormat:
                                  @"%f %f %f %f %f %f %f %f %f %f",
                                  dist[0],dist[1],dist[2],dist[3],dist[4],dist[5],dist[6],dist[7],dist[8],dist[9]
                                  ],
                                 @"OK", nil, nil);
    
    return rating;
}

//-(bool) comparator:(const mypair&) l :(const mypair&) r
//{return l.first<r.first;}

@end