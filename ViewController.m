//
//  ViewController.m
//  LCAnalyzer
//
//  Created by Puttipong Leakkaw on 3/1/2562 BE.
//  Copyright © 2562 dollarandtrump. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#define HEADING_TIMEOUT 30
#define THRESHOLD_ALPHA 1.5

@interface ViewController ()
{
    NSString *documentsDirectory;
    NSString *anz_content;
    
    NSMutableArray*sequense_content;
    NSString*tmp_content;
    BOOL previousIsNeg;
    
    BOOL isFirst;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    documentsDirectory = [paths objectAtIndex:0];
    NSLog(@"file path : %@",documentsDirectory);

    anz_content = @"time,st_phase,nd_phase,duration,avg_speed,lateral_distance(uv),lateral_direction,events,date,filename";
}

- (IBAction)createSteeringFile:(id)sender {
    
    anz_content = @"time,st_phase,nd_phase,duration,avg_speed,lateral_distance(uv),lateral_direction,events,date,filename";

    [self readAllFiles];

    NSLog(@"End...");
}

-(void)readAllFiles
{
    NSString * resourcePath = [[NSBundle mainBundle] resourcePath];
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:resourcePath error:NULL];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"csv"]) {
            
            NSString*fileroot = @"raw";
            
            if([filename containsString:fileroot] && ![filename containsString:@"gt"])//เอาเฉพาะ none LC
            {
                NSLog(@"Reading....%@",filename);
                [self readingFileMagV2:[filename stringByReplacingOccurrencesOfString:@".csv" withString:@""]];
            }
        }
    }];
    
    NSLog(@"\n%@",anz_content);
    
    [self writeFile:[NSArray arrayWithObjects:@"anz_smt",anz_content, nil]];
}

-(void)readingFileMagV2:(NSString*)fname
{
    NSString* fileContents = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fname ofType:@"csv"] encoding:NSUTF8StringEncoding error:NULL];
    NSArray* rows = [fileContents componentsSeparatedByString:@"\n"];
    
    NSMutableArray*heading_frist    = [[NSMutableArray alloc]init];
    NSMutableArray*heading_second    = [[NSMutableArray alloc]init];
    
    NSMutableArray*tmp_error_row    = [[NSMutableArray alloc]init];

    double previous_heading = 9999;
    double current_heading = 0;
    
    sequense_content = [[NSMutableArray alloc]init];
    
    NSString *previous_row = @"";
    
    int phase = 0;
    BOOL isMore = NO;
    BOOL isLess = NO;
    BOOL isStraight = NO;
    float headingThresholds = 9999;
    int sameHeadingCount = 0;
    
    //long cuttingCount = 9999; //3sec
    isFirst = YES;
    
      for (NSString *row in rows)
      {
          NSString*tmp_row = row;
          NSArray* columns = [tmp_row componentsSeparatedByString:@","];
          
          if([[columns[0] lowercaseString] containsString:@"time"])
          {
              continue;
          }
          
          //Mag Collectingrow
          current_heading = lroundf([columns[4] doubleValue]);
          
          //NSLog(@"%f -> %f",[columns[4] doubleValue],current_heading);
          if(previous_heading == 9999){
              previous_heading = current_heading;
              continue;
          }
          
          if(current_heading != previous_heading)
          {
              if(tmp_error_row.count > 0)
              {
                  tmp_row = [NSString stringWithFormat:@"%@,%@,%@,%@,%.0f,%@,%@",columns[0],columns[1],columns[2],columns[3],previous_heading,columns[5],columns[6]];
                  current_heading = previous_heading;
              }
              [tmp_error_row addObject:[NSNumber numberWithDouble:previous_heading]];
          }
          
          //TODO: Phase classifier.
          if(current_heading > previous_heading)
          {
//              if(isStraight)
//              {
//                  isStraight = NO;
//                  phase = 0;
//              }
              
             if(!isMore)
             {
                if(phase > 0)
                {
                    phase++;
                }
                else
                {
                    phase = 1;
                }
                isLess = NO;
                isMore = YES;
             }
          }
          
          if(current_heading < previous_heading)
          {
//              if(isStraight)
//              {
//                  isStraight = NO;
//                  phase = 0;
//              }
              
              if(!isLess)
              {
                    if(phase > 0)
                    {
                        phase++;
                    }
                    else
                    {
                        phase = 1;
                    }
                  
                  isMore = NO;
                  isLess = YES;
              }
          }
          
          if([row containsString:@"18:43:24.574"])
          {
              NSLog(@"test");
          }
           
          
          //TODO: Add data into each phase.
          if(current_heading != previous_heading)
          {
              //cuttingCount = HEADING_TIMEOUT;
              if(phase == 1)
              {
                  if(heading_frist.count < 1){
                      [heading_frist addObject:previous_row];
                  }
                  else{
                      
                      NSLog(@"Get Theresholds Phase 1...");
                      headingThresholds = ceilf([self getDurationThershold:heading_frist phase:phase isReverse:NO]);
                    if(headingThresholds == 0)
                    {
                        headingThresholds = 9999;
                    }
            
                      sameHeadingCount = 0;
                  }
                  
                  [heading_frist addObject:tmp_row];
              }
          
              if(phase == 2)
              {
                  if(heading_second.count<1)
                  {
                      NSArray*first_object = [[heading_frist firstObject] componentsSeparatedByString:@","];
                      NSArray*last_object = [[heading_frist lastObject] componentsSeparatedByString:@","];
                      
                      NSLog(@"Get First Theresholds Phase 2 (phase 1 %@->%@)...",first_object[4],last_object[4]);
                      [heading_second addObjectsFromArray:[self getRecentHeadingOfFirstPhase:heading_frist]];
                      headingThresholds = ceilf([self getDurationThershold:heading_second phase:phase isReverse:NO]);
                      sameHeadingCount = 0;
                  }
                  else
                  {
                      NSLog(@"Get Theresholds Phase 2...");
                      headingThresholds = ceilf([self getDurationThershold:heading_second phase:phase isReverse:NO]);
                      sameHeadingCount = 0;
                  }

                  [heading_second addObject:tmp_row];
              }
              
              if(phase == 3)
              {
                  //NSLog(@"\n%@\n%@",heading_frist,heading_second);
                  NSArray*tmp_secondHeading = [NSArray arrayWithArray:heading_second];

                  [self createAnzFileFromSteeringWithFilename:[self combindTwoPhase:heading_frist second:heading_second] finename:fname isChange:NO];
                  NSLog(@"Create Bump... (Complete)");
                  
                  [heading_frist removeAllObjects];
                  [heading_frist addObjectsFromArray:tmp_secondHeading];
                  [heading_second removeAllObjects];
                  [heading_second addObjectsFromArray:[self getRecentHeadingOfFirstPhase:heading_frist]];
                  [heading_second addObject:tmp_row];

                  phase = 2;
                  sameHeadingCount = 0;
                  
                  NSLog(@"Create New Phase 2 ...");
                  headingThresholds = ceilf([self getDurationThershold:heading_second phase:phase isReverse:NO]);
                  NSLog(@"------------------------------------");
              }
          }
          else
          {
              [tmp_error_row removeAllObjects];
           //TODO: Cutting Over Duplicate Heading.
              sameHeadingCount++;
                if(phase == 1)
                {
                    [heading_frist addObject:tmp_row];
                    
                    if(sameHeadingCount > headingThresholds)
                    {
                        //[self createAnzFileFromSteeringWithFilename:[self combindTwoPhase:heading_frist second:heading_second] finename:fname isChange:NO];
                        NSLog(@"Ignore [%.0f] with thresholds:[%.0f] data:[%.0d]",current_heading,headingThresholds,sameHeadingCount);
                        [heading_frist removeAllObjects];
                        [heading_second removeAllObjects];
                        phase = 0;
                        headingThresholds = 9999;
                        sameHeadingCount = 0;
                        isMore = NO;
                        isLess = NO;
                        NSLog(@"------------------------------------");
                    }
                    
                }
              
                if(phase == 2)
                {
                    [heading_second addObject:tmp_row];
                    
                    if(sameHeadingCount > headingThresholds)
                    {
                        [self createAnzFileFromSteeringWithFilename:[self combindTwoPhase:heading_frist second:heading_second] finename:fname isChange:NO];
                        NSLog(@"Create Bump... (Striaght)");
                        
                        [heading_frist removeAllObjects];
                        [heading_frist addObjectsFromArray:heading_second];
                        [heading_second removeAllObjects];
                        
                        headingThresholds = 9999;
                        phase = 1;
                        sameHeadingCount = 0;
//                        isStraight = YES;
//                        isMore = NO;
//                        isLess = NO;
                        
                        NSLog(@"------------------------------------");
                    }
                }
          }
          
          previous_row = tmp_row;
          previous_heading = current_heading;
      }
    
    
    if(heading_frist.count > 0 && heading_second.count > 0)
    {
        [self createAnzFileFromSteeringWithFilename:[self combindTwoPhase:heading_frist second:heading_second] finename:fname isChange:NO];
    }
}
-(NSArray*)getRecentHeadingOfFirstPhase:(NSMutableArray*)phase
{
    NSMutableArray*lastestHeading = [[NSMutableArray alloc]init];
    long heading = 0;
    for (NSString*row in phase)
    {
        NSArray* columns = [row componentsSeparatedByString:@","];
        
        if(heading != [columns[4] intValue] )
        {
            [lastestHeading removeAllObjects];
            [lastestHeading addObject:row];
        }
        else
        {
            [lastestHeading addObject:row];
        }
        
        heading = [columns[4] intValue];
    }
    
    return lastestHeading;
}

-(NSMutableArray*)combindTwoPhase:(NSMutableArray*)first second:(NSMutableArray*)second
{
 
    //Prepare First Phase
    NSMutableArray*firstPhase   = [[NSMutableArray alloc]initWithArray:[self cuttingHead:first]];
    firstPhase = [[NSMutableArray alloc]initWithArray:[self cuttingOverDuration:firstPhase]];
    firstPhase = [[NSMutableArray alloc]initWithArray:[self cuttingTale:firstPhase]];
    
    //Prepare Second Phase
    NSMutableArray*secondPhase = [[NSMutableArray alloc]initWithArray:[self cuttingTale:second]];;
    //secondPhase = [[NSMutableArray alloc]initWithArray:[self cuttingHead:secondPhase]];
    
    if([firstPhase.lastObject isEqual:secondPhase.firstObject])
    {
        [firstPhase removeLastObject];
    }
    
    NSMutableArray*returnResult = [[NSMutableArray alloc]init];
    [returnResult addObjectsFromArray:firstPhase];
    [returnResult addObjectsFromArray:secondPhase];
    
    //Print Out
    NSArray* Start  = [[firstPhase firstObject] componentsSeparatedByString:@","];
    NSArray* Middle   = [[secondPhase lastObject] componentsSeparatedByString:@","];
    NSArray* End        = [[secondPhase firstObject] componentsSeparatedByString:@","];
    NSLog(@"[%@ - %@] Got Bump ...(%@->%@->%@)",Start[0],End[0],Start[4],Middle[4],End[4]);
    
    return returnResult;
}

-(NSArray*)cuttingHead:(NSMutableArray*)halfBump
{
    NSMutableArray*phase = [[NSMutableArray alloc]initWithArray:halfBump copyItems:YES];
    NSLog(@"Head Cutting...");
    
    int headNumber = 999;
    NSMutableArray*deleteHead = [[NSMutableArray alloc]init];
    
//Remove Over First Phase
    for (long i = 0; i < phase.count; i++)
    {
        NSArray* columns = [phase[i] componentsSeparatedByString:@","];
        
        if(headNumber == 999)
        {
            headNumber = [columns[4]intValue];
            [deleteHead addObject:phase[i]];
            continue;
        }
        
        if(headNumber == [columns[4]intValue])
        {
            [deleteHead addObject:phase[i]];
        }
        else
        {
            [deleteHead removeLastObject];
            i = phase.count+1;
        }
        
        headNumber = [columns[4]intValue];
    }
    [phase removeObjectsInArray:deleteHead];
    
    return phase;
}

-(NSArray*)cuttingTale:(NSMutableArray*)halfBump
{
    NSMutableArray*tales = [[NSMutableArray alloc]initWithArray:halfBump copyItems:YES];
    NSLog(@"Tale Cutting...");
    int taleNumber = 999;

    BOOL isTales = YES;

    NSMutableArray*deleteTale = [[NSMutableArray alloc]init];
    NSMutableArray*tmp_deleteTale;
    
    for (long i = tales.count-1; i >=0 ; i--)
    {
        NSArray* columns = [tales[i] componentsSeparatedByString:@","];

        [deleteTale addObject:tales[i]];
        
        if(taleNumber == 999)
        {
            taleNumber = [columns[4] intValue];
            continue;
        }
        else
        {
            if(taleNumber != [columns[4] intValue])
            {
                if(isTales)
                {
                    tmp_deleteTale = [[NSMutableArray alloc]initWithArray:deleteTale];
                    isTales = NO;
                    i = -1;
                }
            }
        }
        
        taleNumber = [columns[4] intValue];
    }
    
    [tmp_deleteTale removeLastObject];
    [tmp_deleteTale removeLastObject];
    [tales removeObjectsInArray:tmp_deleteTale];
    
    return tales;
}

-(NSArray*)cuttingOverDuration:(NSMutableArray*)halfBump
{
    NSMutableArray*phase = [[NSMutableArray alloc]initWithArray:halfBump copyItems:YES];
    NSLog(@"Head Cutting...");
    
    int headNumber = 999;
    NSMutableArray*deleteHead = [[NSMutableArray alloc]init];
    
    [deleteHead removeAllObjects]; //for reverse phase
    NSMutableArray*tips_delete = [[NSMutableArray alloc]init];
    float head_threshold = 9999;
    float tmp_head_threshold=0;
    headNumber = 999;
    BOOL isOver = NO;

        for (long i = phase.count-1; i >=0 ; i--)
        {
            NSArray* columns = [phase[i] componentsSeparatedByString:@","];
            [deleteHead addObject:phase[i]];
            
            if(headNumber == 999)
            {
                headNumber = [columns[4]intValue];
                continue;
            }
            
            if(!isOver)
            {
                if(headNumber != [columns[4] intValue])
                {
                    [tips_delete removeAllObjects];

                    head_threshold = [self getDurationThershold:deleteHead phase:2 isReverse:YES];
    
                    if(head_threshold == 0)
                    {
                        head_threshold = 9999;
                    }
                    tmp_head_threshold = head_threshold;
                }else
                {
                    [tips_delete addObject:phase[i]];
                    if(head_threshold < 0)
                    {
                        isOver = YES;
                        [deleteHead removeAllObjects];
                        [deleteHead addObject:phase[i]];
                        NSLog(@"Cut Over Head Threshold %i degree > %.0f ms",[columns[4] intValue],tmp_head_threshold);
                    }
                    head_threshold--;
                }
            }
    
            headNumber = [columns[4] intValue];
        }

    if(isOver)
    {
        [deleteHead addObjectsFromArray:tips_delete];
        [phase removeObjectsInArray:deleteHead];
    }
    
     return phase;
}


-(float)getDurationThershold:(NSMutableArray*)bump phase:(int)phase isReverse:(BOOL)isReverse
{
    float duration  = 0;
    int heading     = 9999;
    
    NSMutableArray* bump_copy = [[NSMutableArray alloc]initWithArray:bump copyItems:YES];
    NSMutableArray* deletes = [[NSMutableArray alloc]init];
    
    //Remove First Duration
    if(phase == 1)
    {
        for (long i = 0; i < bump_copy.count; i++)
        {
            NSArray* columns = [bump_copy[i] componentsSeparatedByString:@","];
            if(heading == 9999)
            {
                heading = [columns[4] intValue];
            }
            
            if(heading != [columns[4] intValue])
            {
                i = bump.count;
            }else
            {
                [deletes addObject:bump_copy[i]];
            }
            
            heading = [columns[4] intValue];
        }
        [bump_copy removeObjectsInArray:deletes];
    }
    //Remove First Duration
    int min = 999;
    int max = 0;
    long duration_min = 999;
    long duration_max = 0;
    int calCount = 0;
    
    NSCountedSet *set_head = [[NSCountedSet alloc] initWithArray:[self getOnlyHeadingOfRows:bump_copy]];
    
    for (id item in set_head) {

        long itemCount = (unsigned long)[set_head countForObject:item];
        if(itemCount > 1)
        {
            calCount++;
            duration+=itemCount;
            
            if((unsigned long)[set_head countForObject:item] < duration_min)
            {
                duration_min = (unsigned long)[set_head countForObject:item];
            }
            
            if((unsigned long)[set_head countForObject:item] > duration_max)
            {
                duration_max = (unsigned long)[set_head countForObject:item];
            }
        }
        
        if([item intValue] < min)
        {
            min = [item intValue];
        }
        
        if([item intValue] > max)
        {
            max = [item intValue];
        }
        
        NSLog(@"%@ [%lu]", item, (unsigned long)[set_head countForObject:item]);
    }

    if(calCount == 0)
    {
        NSLog(@"{%i} Duration: FREE Thresholds: INFINITY",phase);
        return INFINITY;
    }
    else
    {
        
        int compensateDegree = 2;
        if(isReverse)
        {
            compensateDegree = 1; //ตอนคิดย้อนมันจะมี องศา หัว-ท้าย ติดมาด้วยอยู่แล้ว
        }
        
        float heading_diff = (max-min)+compensateDegree;
        float AVG = duration/calCount;

        float thresholds = (heading_diff*AVG);
        NSLog(@"{%i} Duration: %.0f Thresholds: %.0f",phase,duration,thresholds);
        //NSLog(@"%.0f = (%.0f/%.0f)+%.0f",thresholds,head_sum,heading_diff,AVG);
        return thresholds;
    }
}

-(NSArray*)getOnlyHeadingOfRows:(NSArray*)content
{
    NSMutableArray*heading = [[NSMutableArray alloc]init];
    for (NSString *row in content)
    {
        NSArray* columns = [row componentsSeparatedByString:@","];
        [heading addObject:[NSNumber numberWithInt:[columns[4] intValue]]];
    }
    
    return heading;
}

-(void)createAnzFileFromSteeringWithFilename:(NSMutableArray*)steeringArray finename:(NSString*)fname isChange:(BOOL)isChange
{
    if(steeringArray)
    {
            NSMutableArray*headingArray         = [[NSMutableArray alloc]init];
            NSMutableArray*speedArray           = [[NSMutableArray alloc]init];
            NSMutableArray*headingArray_phase1  = [[NSMutableArray alloc]init];
            NSMutableArray*headingArray_phase2  = [[NSMutableArray alloc]init];
            NSMutableArray*speedArray_phase1    = [[NSMutableArray alloc]init];
            
            NSArray* first = [[steeringArray firstObject] componentsSeparatedByString:@","];
            NSArray* last = [[steeringArray lastObject] componentsSeparatedByString:@","];
            
            NSString*   event;
            
            CLLocation* LocationStart;
            CLLocation* LocationEnd;
            CLLocationDistance distance = 0;
            
            LocationStart = [[CLLocation alloc]initWithLatitude:[first[2] doubleValue] longitude:[first[3] doubleValue]];
            LocationEnd = [[CLLocation alloc]initWithLatitude:[last[2] doubleValue] longitude:[last[3] doubleValue]];
            distance = [LocationStart distanceFromLocation:LocationEnd];
            
            int headingCount = 0;
            long headingDegree = 999;
            
            BOOL isFirst = YES;
            BOOL isMore = YES;
            BOOL isOnFirstHalf = NO;
            NSMutableArray*firstHalf = [[NSMutableArray alloc]init];
            NSMutableArray*secondHalf = [[NSMutableArray alloc]init];
            
            NSString*previousRow;
            
            for (NSString *row in steeringArray)
            {
                NSArray* columns = [row componentsSeparatedByString:@","];

                [headingArray    addObject:columns[4]];
                [speedArray     addObject:columns[5]];
                
                if(headingDegree != 999)
                {
                    if(headingDegree != [columns[4] integerValue])
                    {
                        headingCount++;

                        if(isFirst)
                        {
                            isOnFirstHalf = YES;
                            isFirst = NO;
                            isMore = headingDegree < [columns[4] integerValue];
                            [firstHalf addObject:previousRow];
                            [headingArray_phase1 addObject:[NSString stringWithFormat:@"%li",headingDegree]];
                        }
                        
                        if(isMore && headingDegree < [columns[4] integerValue])
                        {
                            [firstHalf addObject:row];
                            [headingArray_phase1 addObject:columns[4]];
                            [speedArray_phase1 addObject:columns[5]];
                        }
                        else if(!isMore && headingDegree < [columns[4] integerValue] == NO)
                        {
                            [firstHalf addObject:row];
                            [headingArray_phase1 addObject:columns[4]];
                            [speedArray_phase1 addObject:columns[5]];
                        }
                        else
                        {
                            if(isOnFirstHalf)
                            {
                                isOnFirstHalf = NO;
                                [secondHalf addObject:previousRow];
                                [headingArray_phase2 addObject:[NSString stringWithFormat:@"%li",headingDegree]];
                            }
                            [secondHalf addObject:row];
                            [headingArray_phase2 addObject:columns[4]];
                        }
                    }
                    else
                    {
                        if(isOnFirstHalf)
                        {
                            [firstHalf removeLastObject];
                            [firstHalf addObject:row];
                        }
                        else
                        {
                            [secondHalf removeLastObject];
                            [secondHalf addObject:row];
                        }
                    }
                }
            
                previousRow = row;
                headingDegree = [columns[4] integerValue];

                event = [[columns[6] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet] ]componentsJoinedByString:@" "];
            }
            
        //    NSNumber* begin             = [NSNumber numberWithDouble:[[firstHalf firstObject] doubleValue]];
        //    NSNumber* end               = [NSNumber numberWithDouble:[[firstHalf lastObject] doubleValue]];
            double steering             = [[headingArray_phase1 firstObject] doubleValue]-[[headingArray_phase1 lastObject] doubleValue] ;
            double steering_phase2      = [[headingArray_phase2 firstObject] doubleValue]-[[headingArray_phase2 lastObject] doubleValue] ;
            double steering_abs         = fabs(steering);
            double steering_phase2_abs  = fabs(steering_phase2);
        //    NSNumber* steering_sd           = [self standardDeviationOf:secondHalf];
            
            
            NSArray* phase_1 = [[firstHalf lastObject] componentsSeparatedByString:@","];
            NSString*   phase_1_begin_time  = first[0];
            NSString*   phase_1_end_time    = phase_1[0];
            NSTimeInterval phase_1_minmax_time  = [[self StringToDate:phase_1_begin_time] timeIntervalSinceDate:[self StringToDate:phase_1_end_time]];
            
            NSString*   begin_time  = first[0];
            NSString*   end_time    = last[0];
            NSTimeInterval minmax_time  = [[self StringToDate:begin_time] timeIntervalSinceDate:[self StringToDate:end_time]];
            NSNumber* speed_avg         = [speedArray valueForKeyPath:@"@avg.floatValue"];
            NSString* speed_begin       = [speedArray_phase1 firstObject];
            NSString* speed_end         = [speedArray_phase1 lastObject];
           
        if(fabs(minmax_time) > 100)
        {
            NSLog(@"sdsd");
        }
            NSString*content;
           
            //แปลงเป็น m/s
        //    double avg = 0.00;
            double u = 0.00;
            double v = 0.00;
            double t = 0.00;
            
        //    avg = [speed_avg doubleValue]/3.6;
            u = [speed_begin doubleValue]/3.6;
            v = [speed_end doubleValue]/3.6;
            t = fabs(phase_1_minmax_time);
            
            float sinx = sin(steering_abs/180*M_PI);
            
        //    double lateral_distance_avg = (avg*t)*sinx;
            double lateral_distance_uv = (((u+v)/2)*t)*sinx;

                    //@"time,duration,distance,lateral_distance(uv),events,date,filename";
                    double direction_lateral = lateral_distance_uv;
                    
                    
                    if(steering < 0)
                    {
                        direction_lateral *= -1;
                        
                        if(isFirst)
                        {
                            previousIsNeg = YES;
                            isFirst=NO;
                        }
                    }
                    
            //@"time,st_phase,nd_phase,duration,avg_speed,lateral_distance(uv),lateral_direction,events,date,filename";
            content = [NSString stringWithFormat:@"%@,%.0f,%.0f,%.1f,%.2f,%.2f,%.2f,%@,%@,%@",
                       last[0],
                       steering_abs,
                       steering_phase2_abs,
                       fabs(minmax_time),
                       [speed_avg doubleValue],
                       lateral_distance_uv,
                       direction_lateral,
                       event,
                       [[last[1] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "],
                       fname];
            
            anz_content = [NSString stringWithFormat:@"%@\n%@",anz_content,content];
    }
}

-(void)writeFile:(NSArray*)array{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    documentsDirectory = [paths objectAtIndex:0];
    NSLog(@"file path : %@",documentsDirectory);
    
    NSString*name = array[0];
    NSString*content = array[1];
    
    NSString *fileName = [NSString stringWithFormat:@"%@/%@.csv",
                          documentsDirectory,name];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    
}

- (NSNumber *)standardDeviation:(NSArray*)array {
    double sumOfDifferencesFromMean = 0;
    for (NSNumber *score in array) {
        sumOfDifferencesFromMean += pow(([score doubleValue] - [[array valueForKeyPath:@"@avg.self"] doubleValue]), 2);
    }
    
    NSNumber *standardDeviation = @(sqrt(sumOfDifferencesFromMean / array.count));
    
    return standardDeviation;
}

-(NSNumber*)standardDeviationOf:(NSMutableArray*)array
{
    // Compute array average
    int total = 0;
    NSUInteger count = [array count];
    
    for (NSNumber *item in array) {
        
        total += [item intValue];
    }
    
    double average = 1.0 * total / count;
    
    // Sum difference squares
    double diff, diffTotal = 0;
    
    for (NSNumber *item in array) {
        
        diff = [item doubleValue] - average;
        diffTotal += diff * diff;
    }
    
    // Set variance (average from total differences)
    double variance = diffTotal / count; // -1 if sample std deviation
    
    // Standard Deviation, the square root of variance
    double stdDeviation = sqrt(variance);
    
    return [NSNumber numberWithDouble:stdDeviation];
}

-(NSDate*)StringToDate:(NSString*) str_date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
    NSDate *resultDate = [dateFormatter dateFromString:str_date];
    return resultDate;
}

@end
