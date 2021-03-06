//
//  FXImageView.m
//
//  Version 1.2.3
//
//  Created by Nick Lockwood on 31/10/2011.
//  Copyright (c) 2011 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXImageView
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "FXImageView.h"
#import "UIImage+FX.h"
#import <objc/message.h>

#import "AFImageRequestOperation.h"

@interface NSOperationQueueObserver : NSObject

+ (NSOperationQueueObserver *)sharedQueueObserver;
- (void)observe;

@property (nonatomic, getter = isObserving) BOOL observing;

@end

@implementation NSOperationQueueObserver

+ (NSOperationQueueObserver *)sharedQueueObserver {
    static NSOperationQueueObserver *shareObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareObserver = [[NSOperationQueueObserver alloc] init];
    });
    return shareObserver;
}

- (void)observe {
    if (!self.isObserving) {
        NSOperationQueue *sharedQueue = [FXImageView processingQueue];
        [sharedQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:NULL];
        self.observing = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationCount"]) {
        int operations = [[change objectForKey:@"new"] intValue];
        if (operations == 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    }
}

- (void)dealloc {
    [[FXImageView processingQueue] removeObserver:self forKeyPath:@"operationCount"];
}

@end


@interface FXImageView ()

@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSURL *imageContentURL;
@property (nonatomic, strong) NSMutableDictionary *diskKeys;

- (void)processImage;

@end

@implementation FXImageView

@synthesize asynchronous = _asynchronous;
@synthesize reflectionGap = _reflectionGap;
@synthesize reflectionScale = _reflectionScale;
@synthesize reflectionAlpha = _reflectionAlpha;
@synthesize shadowColor = _shadowColor;
@synthesize shadowOffset = _shadowOffset;
@synthesize shadowBlur = _shadowBlur;
@synthesize cornerRadius = _cornerRadius;
@synthesize customEffectsBlock = _customEffectsBlock;
@synthesize cacheKey = _cacheKey;

@synthesize originalImage = _originalImage;
@synthesize imageView = _imageView;
@synthesize imageContentURL = _imageContentURL;


#pragma mark -
#pragma mark Shared storage

+ (NSOperationQueue *)processingQueue
{
    static NSOperationQueue *sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
        [sharedQueue setMaxConcurrentOperationCount:4];
    });
    return sharedQueue;
}

+ (NSCache *)processedImageCache
{
    static NSCache *sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[NSCache alloc] init];
    });
    return sharedCache;
}


#pragma mark -
#pragma mark Setup

- (void)setUp
{
    self.shadowColor = [UIColor blackColor];
    self.contentMode = UIViewContentModeScaleAspectFill;
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _imageView.contentMode = self.contentMode;
    [self addSubview:_imageView];
    [self setImage:super.image];
    super.image = nil;
    
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [_indicatorView setHidesWhenStopped:YES];
    [_indicatorView setHidden:YES];
    [self addSubview:_progressView];
    [self addSubview:_indicatorView];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [_messageLabel setNumberOfLines:0];
    [_messageLabel setBackgroundColor:[UIColor clearColor]];
    [_messageLabel setFont:[UIFont boldSystemFontOfSize:17]];
    [_messageLabel setTextColor:[UIColor darkGrayColor]];
    [_messageLabel setTextAlignment:NSTextAlignmentCenter];
    [self addSubview:_messageLabel];
    
    [[NSOperationQueueObserver sharedQueueObserver] observe];
    
    self.cacheDirectoryName = @"fximageviewcache";
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    if ((self = [super initWithImage:image]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
    if ((self = [super initWithImage:image highlightedImage:highlightedImage]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

#if !__has_feature(objc_arc)

- (void)dealloc
{
    [_customEffectsBlock release];
    [_cacheKey release];
    [_originalImage release];
    [_shadowColor release];
    [_imageView release];
    [_imageContentURL release];
    [super dealloc];    
}

#endif


#pragma mark -
#pragma mark Caching

- (NSString *)colorHash:(UIColor *)color
{
    NSString *colorString = @"{0.00,0.00}";
    if (color && ![color isEqual:[UIColor clearColor]])
    {
        NSInteger componentCount = CGColorGetNumberOfComponents(color.CGColor);
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        NSMutableArray *parts = [NSMutableArray arrayWithCapacity:componentCount];
        for (int i = 0; i < componentCount; i++)
        {
            [parts addObject:[NSString stringWithFormat:@"%.2f", components[i]]];
        }
        colorString = [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }
    return colorString;
}

- (NSString *)imageHash:(UIImage *)image
{
    static NSInteger hashKey = 1;
    NSString *number = objc_getAssociatedObject(image, @"FXImageHash");
    if (!number && image)
    {
        number = [NSString stringWithFormat:@"%i", hashKey++];
        objc_setAssociatedObject(image, @"FXImageHash", number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return number;
}

- (NSString *)cacheKey
{
    if (_cacheKey) return _cacheKey;
    
    return [NSString stringWithFormat:@"%@_%.2f_%.2f_%.2f_%@_%@_%.2f_%.2f_%i",
            _imageContentURL ?: [self imageHash:_originalImage],
            _reflectionGap,
            _reflectionScale,
            _reflectionAlpha,
            [self colorHash:_shadowColor],
            NSStringFromCGSize(_shadowOffset),
            _shadowBlur,
            _cornerRadius,
            self.contentMode];
}

- (void)cacheProcessedImage:(UIImage *)processedImage forKey:(NSString *)cacheKey {
    [[[self class] processedImageCache] setObject:processedImage forKey:cacheKey];
    [self writeImageToDisk:processedImage key:cacheKey];
}

- (UIImage *)cachedProcessedImage {
    return [self cachedProcessImageForKey:[self cacheKey]];
}

- (UIImage *)cachedProcessImageForKey:(NSString *)key {
    return [[[self class] processedImageCache] objectForKey:key];
}

- (void)writeImageToDisk:(UIImage *)image key:(NSString *)key{
    NSString *hashKey = [NSString stringWithFormat:@"%d", [key hash]];
    if (![self imageExistsOnDiskWithKey:key]) {
        NSData *data = UIImagePNGRepresentation(image);
        NSString *filePath = [self filePathWithKey:hashKey];
        
        NSError *error;
        NSLog(@"Writing image to file: %@", key);
        [data writeToFile:filePath options:NSDataWritingAtomic error:&error];
        if (error) {
            NSLog(@"Cannot write image %@ to path %@", key, filePath);
        } else {
            [self.diskKeys setObject:[NSNull null] forKey:hashKey];
        }
    }    
}

- (NSString *)filePathWithKey:(NSString *)key{
    return [[self cacheDirectoryPath] stringByAppendingPathComponent:key];
}

- (BOOL)imageExistsOnDiskWithKey:(NSString *)key{
	if(_diskKeys) return [_diskKeys objectForKey:[NSString stringWithFormat:@"%d", [key hash]]]==nil ? NO : YES;
    return [[NSFileManager defaultManager] fileExistsAtPath:[self filePathWithKey:key]];
}

- (UIImage*)imageFromDiskWithKey:(NSString*)key{
	NSData *data = [NSData dataWithContentsOfFile:[self filePathWithKey:[NSString stringWithFormat:@"%d", [key hash]]]];
	return [[UIImage alloc] initWithData:data];
}

#pragma mark Path Methods
- (void) _setupFolderDirectory{	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *path = [self cacheDirectoryPath];
	
	BOOL isDirectory = NO;
	BOOL folderExists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
	
	if (!folderExists){
		NSError *error = nil;
		[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	}
}

- (void) setCacheDirectoryName:(NSString *)str{
	_cacheDirectoryPath=nil;
	_cacheDirectoryName = [str copy];
	
	[self _setupFolderDirectory];
	
	
	NSError* error = nil;
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self cacheDirectoryPath] error:&error];
	
	if(error) return;
	
	NSMutableArray *ar = [NSMutableArray arrayWithCapacity:files.count];
	for(NSObject *obj in files)
		[ar addObject:[NSNull null]];
	
	_diskKeys = [[NSMutableDictionary alloc] initWithObjects:ar forKeys:files];
}

- (NSString *) cacheDirectoryPath{
	if(_cacheDirectoryPath==nil){
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		NSString *str = [documentsDirectory stringByAppendingPathComponent:_cacheDirectoryName];
		_cacheDirectoryPath = [str copy];
	}
	return _cacheDirectoryPath;
}

#pragma mark -
#pragma mark Processing

- (void)setProcessedImageOnMainThread:(NSArray *)array
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //get images
        NSString *url = [array objectAtIndex:2];
        url = ([url isKindOfClass:[NSNull class]])? nil:url;
        NSString *cacheKey = [array objectAtIndex:1];
        UIImage *processedImage = [array objectAtIndex:0];
        processedImage = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
        
        //set image
        if ([[self cacheKey] isEqualToString:cacheKey] && [url isEqualToString:self.imageContentURL.absoluteString])
        {
            //implement crossfade transition without needing to import QuartzCore
            
            id animation = objc_msgSend(NSClassFromString(@"CATransition"), @selector(animation));
            objc_msgSend(animation, @selector(setType:), @"kCATransitionFade");
            objc_msgSend(self.layer, @selector(addAnimation:forKey:), animation, nil);
            
            //set processed image
            [self willChangeValueForKey:@"processedImage"];
            _imageView.image = processedImage;
            [self didChangeValueForKey:@"processedImage"];
            
            if (processedImage) {
                [self.messageLabel setHidden:YES];
            } else {
                [self.messageLabel setHidden:NO];
                [self setNeedsLayout];
                [self layoutIfNeeded];
            }
            [self.progressView setHidden:YES];
            [self.indicatorView stopAnimating];
        }
    });
}

- (void)processImageWithURL:(NSString *)url {
    //get properties
    NSString *cacheKey = url;
    UIImage *image = _originalImage;
    UIImage *placeholder = _placeholderImage;
    CGSize size = self.bounds.size;
    CGFloat reflectionGap = _reflectionGap;
    CGFloat reflectionScale = _reflectionScale;
    CGFloat reflectionAlpha = _reflectionAlpha;
    UIColor *shadowColor = _shadowColor;
    CGSize shadowOffset = _shadowOffset;
    CGFloat shadowBlur = _shadowBlur;
    CGFloat cornerRadius = _cornerRadius;
    UIImage *(^customEffectsBlock)(UIImage *image) = [_customEffectsBlock copy];
    UIViewContentMode contentMode = self.contentMode;
    
#if !__has_feature(objc_arc)
    
    [[image retain] autorelease];
    [[imageURL retain] autorelease];
    [[shadowColor retain] autorelease];
    [customEffectsBlock autorelease];
    
#endif
    
    //check cache
    UIImage *processedImage = [self cachedProcessImageForKey:cacheKey];
    if (!processedImage)
    {
        if (image)
        {
            //crop and scale image
            processedImage = [image imageCroppedAndScaledToSize:size
                                                    contentMode:contentMode
                                                       padToFit:NO];
            
            //apply custom processing
            if (customEffectsBlock)
            {
                processedImage = customEffectsBlock(processedImage);
            }
            
            //clip corners
            if (cornerRadius)
            {
                processedImage = [processedImage imageWithCornerRadius:cornerRadius];
            }
            
            //apply shadow
            if (shadowColor && ![shadowColor isEqual:[UIColor clearColor]] &&
                (shadowBlur || !CGSizeEqualToSize(shadowOffset, CGSizeZero)))
            {
                reflectionGap -= 2.0f * (fabsf(shadowOffset.height) + shadowBlur);
                processedImage = [processedImage imageWithShadowColor:shadowColor
                                                               offset:shadowOffset
                                                                 blur:shadowBlur];
            }
            
            //apply reflection
            if (reflectionScale && reflectionAlpha)
            {
                processedImage = [processedImage imageWithReflectionWithScale:reflectionScale
                                                                          gap:reflectionGap
                                                                        alpha:reflectionAlpha];
            }
        } else {
            processedImage = placeholder;
        }
    }
    
    if (processedImage)
    {
        //cache image
        [self cacheProcessedImage:processedImage forKey:cacheKey];
    }
    
    
    //cache and set image
    [self setProcessedImageOnMainThread:@[processedImage?:[NSNull null], cacheKey, url?:[NSNull null]]];
}

- (void)processImage {
    [self processImageWithURL:nil];
}

- (void)queueProcessingOperation:(NSOperation *)operation
{
    //suspend operation queue
    NSOperationQueue *queue = [[self class] processingQueue];
    [queue setSuspended:YES];
    
    //check for existing operations
    if ([operation isKindOfClass:[AFImageRequestOperation class]]) {
        for (AFImageRequestOperation *op in queue.operations)
        {
            if ([op isKindOfClass:[AFImageRequestOperation class]])
            {
                AFImageRequestOperation *oper = (AFImageRequestOperation *)operation;
                if ([op.request isEqual:oper.request])
                {
                    //already queued
                    [queue setSuspended:NO];
                    return;
                }
            }
        }
    }
    
    //make op a dependency of all queued ops
    NSInteger maxOperations = ([queue maxConcurrentOperationCount] > 0) ? [queue maxConcurrentOperationCount]: INT_MAX;
    NSInteger index = [queue operationCount] - maxOperations;
    if (index >= 0)
    {
        NSOperation *op = [[queue operations] objectAtIndex:index];
        if (![op isExecuting])
        {
            [operation removeDependency:op];
            [op addDependency:operation];
        }
    }
    
    //add operation to queue
    [queue addOperation:operation];
    
    //resume queue
    [queue setSuspended:NO];
}

- (void)queueImageForProcessing
{
    UIImage *processedImage = [self cachedProcessImageForKey:self.imageContentURL.absoluteString];
    if (processedImage) {
        _imageView.image = processedImage;
        return;
    } else {
        if ([self imageExistsOnDiskWithKey:self.imageContentURL.absoluteString]) {
            if (!self.shouldHideIndicatorView) {
                [self.indicatorView startAnimating];
                [self.indicatorView setHidden:NO];
            }
            NSString *key = self.imageContentURL.absoluteString;
            __weak FXImageView *weakSelf = self;
            [self showPlaceholderImage];
            NSLog(@"Reading image %@ from disk", self.imageContentURL.absoluteString);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                __strong FXImageView *strongSelf = weakSelf;
                UIImage *image = [strongSelf imageFromDiskWithKey:key];
                if (image) {
                        strongSelf.originalImage = image;
                        [strongSelf processImageWithURL:key];
                }
            });
            return;
        }
    }
    
    [self showPlaceholderImage];
    if (!self.shouldHideIndicatorView) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
    }
    [self.progressView setProgress:0];
    [self.progressView setHidden:NO];
    
    __weak FXImageView *weakSelf = self;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.imageContentURL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    AFImageRequestOperation *imageOperation = [[AFImageRequestOperation alloc] initWithRequest:request];
    __weak AFImageRequestOperation *weakImageOperation = imageOperation;
    
    [imageOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        __strong FXImageView *strongSelf = weakSelf;
        __strong AFImageRequestOperation *strongImageOperation = weakImageOperation;
        if ([strongImageOperation.request.URL isEqual: strongSelf.imageContentURL]) {
            if (![strongSelf cachedProcessImageForKey:strongImageOperation.request.URL.absoluteString]) {
                    if ((float)totalBytesRead/(float)totalBytesExpectedToRead  < 1) {
                        [strongSelf.messageLabel setText:nil];
                        [strongSelf.messageLabel setHidden:YES];
                        
                        if (!self.shouldHideIndicatorView) {
                            [self.indicatorView startAnimating];
                            [self.indicatorView setHidden:NO];
                        }
                    }
                    [strongSelf.progressView setHidden:NO];
                    [strongSelf setNeedsLayout];

                    [strongSelf.progressView setProgress:(float)totalBytesRead/(float)totalBytesExpectedToRead animated:NO];
                    if (totalBytesRead == totalBytesExpectedToRead) {
                        [strongSelf.progressView setHidden:YES];
                    }
            }
        }
    }];
    
    [imageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        __strong FXImageView *strongSelf = weakSelf;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (responseObject) {
                strongSelf.originalImage = responseObject;
                [strongSelf processImageWithURL:operation.request.URL.absoluteString];
            } else {
                strongSelf.originalImage = nil;
                [strongSelf setProcessedImageOnMainThread:@[[NSNull null], operation.request.URL.absoluteString, operation.request.URL.absoluteString]];
            }
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([operation.request.URL.absoluteString isEqualToString:self.imageContentURL.absoluteString]) {
            __strong FXImageView *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.messageLabel setText:NSLocalizedString(@"Image cannot be downloaded", nil)];
                [strongSelf.messageLabel setHidden:NO];
            });
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                strongSelf.originalImage = nil;
                [strongSelf setProcessedImageOnMainThread:@[[NSNull null], operation.request.URL.absoluteString, operation.request.URL.absoluteString]];
            });
        }
    }];
    
    [self queueProcessingOperation:imageOperation];
}

- (void)layoutSubviews
{
    _imageView.frame = self.bounds;
    if (_imageContentURL || self.image)
    {
       // [self updateProcessedImage];
    }
    
    if (!self.indicatorView.hidden) {
        [self.indicatorView setCenter:CGPointMake(CGRectGetWidth(self.imageView.frame)/2, CGRectGetHeight(self.imageView.frame)/2 - CGRectGetHeight(self.indicatorView.frame)/2 - 5)];
    }
    
    if (!self.progressView.hidden) {
        CGRect frame = self.progressView.frame;
        frame.size.width = 0.8 * CGRectGetWidth(self.imageView.frame);
        self.progressView.frame = frame;
        if (self.indicatorView.hidden) {
            [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.imageView.frame)/2, CGRectGetHeight(self.imageView.frame)/2)];
        } else {
            [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.imageView.frame)/2, CGRectGetHeight(self.imageView.frame)/2 + CGRectGetHeight(self.progressView.frame)/2 + 5 )];
        }
    }
    
    if (!self.messageLabel.hidden) {
        CGRect frame = self.messageLabel.frame;
        frame.size.width = 0.8 * CGRectGetWidth(self.imageView.frame);
        self.messageLabel.frame = frame;
        [self.messageLabel sizeToFit];
        [self.messageLabel setCenter:CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2)];
    }
}

- (void)showPlaceholderImage {
    _imageView.image = self.placeholderImage;
}


#pragma mark -
#pragma mark Setters and getters

- (void)setProgressView:(UIProgressView *)progressView {
    if (_progressView != progressView) {
        [_progressView removeFromSuperview];
        _progressView = progressView;
        [self addSubview:_progressView];
    }
}

- (void)setIndicatorView:(UIActivityIndicatorView *)indicatorView {
    if (_indicatorView != indicatorView) {
        [_indicatorView removeFromSuperview];
        _indicatorView = indicatorView;
        [self addSubview:_indicatorView];
    }
}

- (UIImage *)processedImage
{
    return _imageView.image;
}

- (void)setProcessedImage:(UIImage *)image
{
    self.imageContentURL = nil;
    [self willChangeValueForKey:@"image"];
    self.originalImage = nil;
    [self didChangeValueForKey:@"image"];
    _imageView.image = image;
}

- (UIImage *)image
{
    return _originalImage;
}

- (void)setImage:(UIImage *)image
{
    if (_imageContentURL || ![image isEqual:_originalImage])
    {        
        //update processed image
        self.imageContentURL = nil;
        self.originalImage = image;
    }
}

- (void)setReflectionGap:(CGFloat)reflectionGap
{
    if (_reflectionGap != reflectionGap)
    {
        _reflectionGap = reflectionGap;
        [self setNeedsLayout];
    }
}

- (void)setReflectionScale:(CGFloat)reflectionScale
{
    if (_reflectionScale != reflectionScale)
    {
        _reflectionScale = reflectionScale;
        [self setNeedsLayout];
    }
}

- (void)setReflectionAlpha:(CGFloat)reflectionAlpha
{
    if (_reflectionAlpha != reflectionAlpha)
    {
        _reflectionAlpha = reflectionAlpha;
        [self setNeedsLayout];
    }
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    if (![_shadowColor isEqual:shadowColor])
    {
        
#if !__has_feature(objc_arc)
        
        [_shadowColor release];
        _shadowColor = [shadowColor retain];
        
#else
        
        _shadowColor = shadowColor;
        
#endif
        
        [self setNeedsLayout];
    }
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
    if (!CGSizeEqualToSize(_shadowOffset, shadowOffset))
    {
        _shadowOffset = shadowOffset;
        [self setNeedsLayout];
    }
}

- (void)setShadowBlur:(CGFloat)shadowBlur
{
    if (_shadowBlur != shadowBlur)
    {
        _shadowBlur = shadowBlur;
        [self setNeedsLayout];
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (self.contentMode != contentMode)
    {
        super.contentMode = contentMode;
        [self setNeedsLayout];
    }
}

- (void)setCustomEffectsBlock:(UIImage *(^)(UIImage *))customEffectsBlock
{
    if (![customEffectsBlock isEqual:_customEffectsBlock])
    {
        _customEffectsBlock = [customEffectsBlock copy];
        [self setNeedsLayout];
    }
}

- (void)setCacheKey:(NSString *)cacheKey
{
    if (![cacheKey isEqual:_cacheKey])
    {
        _cacheKey = [cacheKey copy];
        [self setNeedsLayout];
    }
}


#pragma mark -
#pragma mark loading

- (void)setImageWithContentsOfFile:(NSString *)file
{
    if ([[file pathExtension] length] == 0)
    {
        file = [file stringByAppendingPathExtension:@"png"];
    }
    if (![file isAbsolutePath])
    {
        file = [[NSBundle mainBundle] pathForResource:file ofType:nil];
    }
    if ([UIScreen mainScreen].scale == 2.0f)
    {
        NSString *temp = [[[file stringByDeletingPathExtension] stringByAppendingString:@"@2x"] stringByAppendingPathExtension:[file pathExtension]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:temp])
        {
            file = temp;
        }
    }
    [self setImageWithContentsOfURL:[NSURL fileURLWithPath:file]];
}

- (void)setImageWithContentsOfURL:(NSURL *)URL
{
    [self setImageWithContentsOfURL:URL placeholderImage:nil];
}

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage {    
    if (![URL isEqual:_imageContentURL])
    {
        [self.messageLabel setText:nil];
        [self.messageLabel setHidden:YES];
        [self.progressView setHidden:YES];
        [self setNeedsLayout];
        
        //update processed image
        
        [self willChangeValueForKey:@"image"];
        self.originalImage = nil;
        [self didChangeValueForKey:@"image"];
        _imageContentURL = URL;
        self.cacheKey = self.imageContentURL.absoluteString;
        
        self.placeholderImage = placeholderImage;
        
        [self queueImageForProcessing];
    }
}

@end
