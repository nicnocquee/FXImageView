//
//  ImageViewCell.h
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FXImageView;

@interface ImageViewCell : UITableViewCell

@property (nonatomic, strong) FXImageView *fxImageView;

- (void)setImageURL:(NSURL *)imageURL;

@end
