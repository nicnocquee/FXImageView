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
@property (nonatomic, strong) UILabel *cellLabel;
@end

@implementation ImageViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fxImageView = [[FXImageView alloc] initWithFrame:CGRectInset(self.contentView.bounds, 10, 10)];
        [_fxImageView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_fxImageView setAsynchronous:YES];
        [_fxImageView setShouldHideIndicatorView:YES];
        [_fxImageView setBackgroundColor:[UIColor whiteColor]];
        [self.contentView addSubview:_fxImageView];
        
        _cellLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.contentView.bounds) - 20, 44)];
        [_cellLabel setBackgroundColor:[UIColor clearColor]];
        [_cellLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_cellLabel setTextColor:[UIColor whiteColor]];
        [_cellLabel setNumberOfLines:0];
        [_cellLabel setFont:[UIFont boldSystemFontOfSize:17]];
        [self.contentView addSubview:_cellLabel];
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
    
    [self.cellLabel sizeToFit];
    CGRect frame = self.cellLabel.frame;
    frame.origin.x = 10;
    self.cellLabel.frame = frame;
    [self.cellLabel setCenter:CGPointMake(self.cellLabel.center.x, CGRectGetHeight(self.contentView.frame) - CGRectGetHeight(self.cellLabel.frame)/2 - 10)];
    
    [self.cellLabel.layer setShadowColor:[UIColor darkGrayColor].CGColor];
    [self.cellLabel.layer setShadowOffset:CGSizeMake(2, 2)];
    [self.cellLabel.layer setShadowOpacity:0.6];
    [self.cellLabel.layer setShadowRadius:1];
}

- (void)setImageURL:(NSURL *)imageURL placeholderImage:(UIImage *)placeholderImage{
    [self.fxImageView setImageWithContentsOfURL:imageURL placeholderImage:placeholderImage];
}

- (void)setCellText:(NSString *)text {
    [self.cellLabel setText:text];
}

@end
