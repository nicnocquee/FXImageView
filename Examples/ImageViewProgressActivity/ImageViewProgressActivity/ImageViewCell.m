//
//  ImageViewCell.m
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "ImageViewCell.h"

#import "FXImageView.h"

#import <QuartzCore/QuartzCore.h>

@interface ImageViewCell ()
@end

@implementation ImageViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fxImageView = [[FXImageView alloc] initWithFrame:CGRectInset(self.contentView.bounds, 10, 10)];
        [_fxImageView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_fxImageView setAsynchronous:YES];
        [_fxImageView setShouldHideIndicatorView:NO];
        [_fxImageView setBackgroundColor:[UIColor whiteColor]];
        [self.contentView addSubview:_fxImageView];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.fxImageView.layer setShadowColor:[UIColor darkGrayColor].CGColor];
    [self.fxImageView.layer setShadowOffset:CGSizeMake(2, 2)];
    [self.fxImageView.layer setShadowOpacity:0.6];
    [self.fxImageView.layer setShadowPath:[UIBezierPath bezierPathWithRect:_fxImageView.bounds].CGPath];
    [self.fxImageView.layer setShadowRadius:1];
    
}

- (void)setImageURL:(NSURL *)imageURL placeholderImage:(UIImage *)placeholderImage{
    [self.fxImageView setImageWithContentsOfURL:imageURL placeholderImage:placeholderImage];
}

@end
