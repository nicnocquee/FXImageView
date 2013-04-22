//
//  ImageViewCell.m
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "ImageViewCell.h"

#import "FXImageView.h"

@implementation ImageViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fxImageView = [[FXImageView alloc] initWithFrame:CGRectInset(self.contentView.bounds, 10, 10)];
        [_fxImageView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_fxImageView setBackgroundColor:[UIColor lightGrayColor]];
        [self.contentView addSubview:_fxImageView];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setImageURL:(NSURL *)imageURL {
    [self.fxImageView setImageWithContentsOfURL:imageURL];
}

@end
