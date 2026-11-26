import { PrismaClient } from "@prisma/client";

export interface HardcodedHondaColour {
  name: string;
  hex: string;
  imageUrl: string | null;
}

export interface HardcodedHondaVehicle {
  code: string;
  name: string;
  category: "MC" | "Scooter" | "BigBike";
  division: "RedWing" | "BigWing";
  ccDisplacement: number;
  exShowroomPrice: number;
  onRoadPrice: number;
  brochureUrl: string | null;
  listingImageUrl: string | null;
  detailImageUrl: string | null;
  colours: HardcodedHondaColour[];
}

// Official catalog sourced from https://www.honda2wheelersindia.com/
export const HONDA_2WHEELERS_CATALOG: HardcodedHondaVehicle[] = [
  {
    "code": "SHN100",
    "name": "Shine 100",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 100,
    "exShowroomPrice": 66900,
    "onRoadPrice": 77270,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/pdf/Honda-Shine-Brochure-New-Look---Print-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/Shine-100.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/Colours/Blue_with_Black.png",
    "colours": [
      {
        "name": "Blue with Black",
        "hex": "#a11a16",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/Colours/Blue_with_Black.png"
      },
      {
        "name": "Gray with Black",
        "hex": "#0063ad",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/Colours/Gray_with_Black.png"
      },
      {
        "name": "Green with Black",
        "hex": "#6b6a69",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/Colours/Green_with_Black.png"
      },
      {
        "name": "Orange with Black",
        "hex": "#00666a",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Shine-100/Colours/Orange_with_Black.png"
      }
    ]
  },
  {
    "code": "SHN100DX",
    "name": "Shine 100 DX",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 100,
    "exShowroomPrice": 72500,
    "onRoadPrice": 83738,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/Brochure/Shine100-DX.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/PLP/Shine100-DX.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/color/Honda-Shine-100-DX-Color2.png",
    "colours": [
      {
        "name": "Pearl Igneous Black",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/color/Honda-Shine-100-DX-Color2.png"
      },
      {
        "name": "Athletic Blue Metallic",
        "hex": "#0063ad",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/color/Honda-Shine-100-DX-Color3.png"
      },
      {
        "name": "Geny Gray Metallic",
        "hex": "#6b6a69",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-100-dx/color/Honda-Shine-100-DX-Color1.png"
      }
    ]
  },
  {
    "code": "LIVO",
    "name": "Livo",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 110,
    "exShowroomPrice": 81651,
    "onRoadPrice": 94307,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/livo/Brochure/Livo.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/Livo.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/livo/Colours/PEARL_IGNEOUS_BLACK_gray_shroud_blue_strip.png",
    "colours": [
      {
        "name": "Pearl Igneous Black (Geny Gray Shroud + Blue Stripes)",
        "hex": "#0063ad",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/livo/Colours/PEARL_IGNEOUS_BLACK_gray_shroud_blue_strip.png"
      },
      {
        "name": "Pearl Igneous Black (Pearl Igneous Black Shroud + Orange Stripes)",
        "hex": "#d1582c",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/livo/Colours/PEARL_IGNEOUS_BLACK_black_shroud_orange_strip.png"
      }
    ]
  },
  {
    "code": "SHN125",
    "name": "Shine 125",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 85800,
    "onRoadPrice": 99099,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Brochure/new/Shine-125-BROCHURE-3rd-Mar-Digital-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/shine125.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Colours/Matte_Axis_Gray_Metallic.png",
    "colours": [
      {
        "name": "Matte Axis Gray Metallic",
        "hex": "#545864",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Colours/Matte_Axis_Gray_Metallic.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Colours/Pearl_Igneous_Black.png"
      },
      {
        "name": "Pearl Siren Blue",
        "hex": "#21222B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Colours/Pearl_Siren_Blue.png"
      },
      {
        "name": "Rebel Red Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Colours/Rebel_Red_Metallic.png"
      },
      {
        "name": "Geny Gray Metallic",
        "hex": "#585858",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125/Geny_Gray_Metallic.png"
      }
    ]
  },
  {
    "code": "SHN125LE",
    "name": "Shine 125 Limited Edition",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 88900,
    "onRoadPrice": 102680,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/Shine-125-Limited-Edition/pdf/shine-125-limited-edition.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125-limited-edition/EMI-Calculator/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125-limited-edition/EMI-Calculator/EMI-Calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/shine-125-limited-edition/EMI-Calculator/EMI-Calculator.png"
      }
    ]
  },
  {
    "code": "SP125",
    "name": "SP 125",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 91771,
    "onRoadPrice": 105996,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Brochure/1388515_SP-brochure-25_Final-_-for-web.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/SP125/ProductEMICalculator/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-125/Colours/Imperial_Red_Metallic_sp125.png",
    "colours": [
      {
        "name": "Imperial Red Metallic",
        "hex": "#96141b",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-125/Colours/Imperial_Red_Metallic_sp125.png"
      },
      {
        "name": "Mat Axis Grey Metallic​",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-125/Colours/Mat_Axis_Grey_Metallic_sp125.png"
      },
      {
        "name": "Mat Marvel Blue Metallic​",
        "hex": "#0666b0",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-125/Colours/Mat_Marvel_Blue_Metallic_sp125.png"
      },
      {
        "name": "Pearl Igneous Black​",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-125/Colours/Pearl_Igneous_Black_sp125.png"
      }
    ]
  },
  {
    "code": "CB125H",
    "name": "CB125 Hornet",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 109900,
    "onRoadPrice": 126935,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB-125/pdf/21072025Bike-Brochure_With-Wing-Mark-Logo-_-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/CB125-Hornet/ProductEMICalculator/EMI-Calculator-CB125.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/CB125-Hornet/360/PEARL-SIREN-BLUE--SPORTS-RED-copy.png",
    "colours": [
      {
        "name": "Pearl Siren Blue with Sports Red",
        "hex": "#a11a16",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/CB125-Hornet/360/PEARL-SIREN-BLUE--SPORTS-RED-copy.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#a11a16",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/CB125-Hornet/360/PEARL-IGNEOUS-BLACK-copy.png"
      },
      {
        "name": "Pearl Siren Blue with Athletic Blue Metallic",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/CB125-Hornet/360/PEARL-SIREN-BLUEATHLETIC-BLUE-METALLIC-copy.png"
      }
    ]
  },
  {
    "code": "UNICORN",
    "name": "Unicorn",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 160,
    "exShowroomPrice": 119481,
    "onRoadPrice": 138001,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Unicorn/Brochure/Unicorn-Brochure-New-Design-_-12-12-24-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/Unicorn.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Unicorn/Matt_Axis_Grey_Metallic.png",
    "colours": [
      {
        "name": "Matt Axis Grey Metallic",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Unicorn/Matt_Axis_Grey_Metallic.png"
      },
      {
        "name": "Radiant Red Metallic",
        "hex": "#96141b",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Unicorn/RADIANT_RED_MET_ALLIC.png"
      }
    ]
  },
  {
    "code": "SP160",
    "name": "SP 160",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 160,
    "exShowroomPrice": 121951,
    "onRoadPrice": 140853,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Brochure/1388515_SP-brochure-25_Final-_-for-web.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/SP-160.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Colours/Pearl_Igneous_Black.png",
    "colours": [
      {
        "name": "Pearl Igneous Black",
        "hex": "#1c1d21",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Colours/Pearl_Igneous_Black.png"
      },
      {
        "name": "Pearl Deep Ground Gray",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Colours/Pearl_Deep_Ground_Gray.png"
      },
      {
        "name": "Athletic Blue Metallic",
        "hex": "#00268C",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/sp-160/Colours/Athletic_Blue_Metallic.png"
      }
    ]
  },
  {
    "code": "NX200RW",
    "name": "NX200 (RedWing)",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 184,
    "exShowroomPrice": 168499,
    "onRoadPrice": 194616,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Brochure/NX200-brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/nx200-emi-calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Decent_Blue_Metallic.png",
    "colours": [
      {
        "name": "Athletic Blue Metallic",
        "hex": "#194C75",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Decent_Blue_Metallic.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Pearl_Nightstar_Black.png"
      }
    ]
  },
  {
    "code": "HORNET2RW",
    "name": "Hornet 2.0 (RedWing)",
    "category": "MC",
    "division": "RedWing",
    "ccDisplacement": 184,
    "exShowroomPrice": 143451,
    "onRoadPrice": 165686,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/hornet-2-0/pdf/Hornet-20.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/Hornet.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/hornet-2-0/360/Matte-Axis-Grey-Metallic.png",
    "colours": [
      {
        "name": "Matte Axis Grey Metallic",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/hornet-2-0/360/Matte-Axis-Grey-Metallic.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/hornet-2-0/360/Pearl-Igneous-Black.png"
      },
      {
        "name": "Radiant Red Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Redwings/hornet-2-0/360/Radiant-Red-Metallic.png"
      }
    ]
  },
  {
    "code": "REBEL500",
    "name": "Rebel 500",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 500,
    "exShowroomPrice": 449900,
    "onRoadPrice": 519635,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel500-bigwing/Spec-Sheets-600x800px_Rebel_500-02_new.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel500-bigwing/Spec-Sheets-600x800px_Rebel_500-02.jpg",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel500-bigwing/Spec-Sheets-600x800px_Rebel_500-02.jpg",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel500-bigwing/Spec-Sheets-600x800px_Rebel_500-02.jpg"
      }
    ]
  },
  {
    "code": "NX200BW",
    "name": "NX200 (BigWing)",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 184,
    "exShowroomPrice": 168499,
    "onRoadPrice": 194616,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200BigWing/calculator/Nx200-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Pearl_Nightstar_Black.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Pearl_Nightstar_Black.png",
    "colours": [
      {
        "name": "Pearl Igneous Black",
        "hex": "#BA1D2E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Pearl_Nightstar_Black.png"
      },
      {
        "name": "Athletic Blue Metallic",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx200/Colours/Decent_Blue_Metallic.png"
      }
    ]
  },
  {
    "code": "HORNET2BW",
    "name": "Hornet 2.0 (BigWing)",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 184,
    "exShowroomPrice": 143451,
    "onRoadPrice": 165686,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/Hornet2-0/Hornet_20_Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Horent-20/360-color-images/Matte-Axis-Grey-Metallic.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Horent-20/360-color-images/Matte-Axis-Grey-Metallic.png",
    "colours": [
      {
        "name": "Matte Axis Grey Metallic",
        "hex": "#00268C",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Horent-20/360-color-images/Matte-Axis-Grey-Metallic.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Horent-20/360-color-images/Pearl-Igneous-Black.png"
      },
      {
        "name": "Radiant Red Metallic",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Horent-20/360-color-images/Radiant-Red-Metallic.png"
      }
    ]
  },
  {
    "code": "REBEL300",
    "name": "Rebel 300",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 300,
    "exShowroomPrice": 325000,
    "onRoadPrice": 375375,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel300-bigwing/Spec-Sheets-600x800px_Rebel-300.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel300-bigwing/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel300-bigwing/Honda-Rebel-300_Black-Color-Shot.png",
    "colours": [
      {
        "name": "Pearl Igneous Black",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/rebel300-bigwing/Honda-Rebel-300_Black-Color-Shot.png"
      }
    ]
  },
  {
    "code": "XR300L",
    "name": "XR300L",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 300,
    "exShowroomPrice": 183000,
    "onRoadPrice": 211365,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300l/XR-300L.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300l/nav/meta-white-side.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300l/nav/meta-white-side.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300l/nav/meta-white-side.png"
      }
    ]
  },
  {
    "code": "XR300RL",
    "name": "XR300 Rally",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 300,
    "exShowroomPrice": 199900,
    "onRoadPrice": 230885,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300rally/XR-300-Rally.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300rally/nav/meta-Rally-red-side.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300rally/nav/meta-Rally-red-side.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/xr300rally/nav/meta-Rally-red-side.png"
      }
    ]
  },
  {
    "code": "CB350",
    "name": "CB350",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 214800,
    "onRoadPrice": 248094,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/bigwing-1/CB350/CB350-brochure-2025.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/Desktop/CB350-DLX.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-RebelRed_Metalic_DLX_360/1.png",
    "colours": [
      {
        "name": "DLX Rebel Red Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-RebelRed_Metalic_DLX_360/1.png"
      },
      {
        "name": "DLX Mat Axis Grey Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Mat-Axis-Grey-Mettalic_DLX_360/1.png"
      },
      {
        "name": "DLX Mat Dune Brown",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Mat-Dune-Brown_DLX_360/1.png"
      },
      {
        "name": "DLX Pearl Deep Ground Grey",
        "hex": "#C1B494",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Pearl-Deep-Ground-Grey_DLX_360/1.png"
      },
      {
        "name": "DLX Pearl Igneous Black",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Pearl-Igneous-Black_DLX_360/1.png"
      }
    ]
  },
  {
    "code": "CB350_26",
    "name": "CB350 (2026)",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 218000,
    "onRoadPrice": 251790,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350-2026/33216_Honda-350-Brochure-Low-Res-(3).pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350-2026/Calculator/EMI-Calculator_1038x638.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350-2026/Calculator/EMI-Calculator_1038x638.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350-2026/Calculator/EMI-Calculator_1038x638.png"
      }
    ]
  },
  {
    "code": "CB350C",
    "name": "CB350C",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 216300,
    "onRoadPrice": 249827,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C/pdf/CB350C_Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C/Calculator/EMI-Calculator_1038x638.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-RebelRed_Metalic_DLX_360/1.png",
    "colours": [
      {
        "name": "DLX Rebel Red Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-RebelRed_Metalic_DLX_360/1.png"
      },
      {
        "name": "DLX Mat Axis Grey Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Mat-Axis-Grey-Mettalic_DLX_360/1.png"
      },
      {
        "name": "DLX Mat Dune Brown",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Mat-Dune-Brown_DLX_360/1.png"
      },
      {
        "name": "DLX Pearl Deep Ground Grey",
        "hex": "#C1B494",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Pearl-Deep-Ground-Grey_DLX_360/1.png"
      },
      {
        "name": "DLX Pearl Igneous Black",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350/DLX/Bigwing_350_CSS-Pearl-Igneous-Black_DLX_360/1.png"
      }
    ]
  },
  {
    "code": "CB350CSE",
    "name": "CB350C Special Edition",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 221900,
    "onRoadPrice": 256295,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C-Anniversary-Edition/special-editition-CB350C-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C-Anniversary-Edition/Technology/CB350C-Special-Edition_HSTC-1120x623-pxl.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C-Anniversary-Edition/Technology/CB350C-Special-Edition_HSTC-1120x623-pxl.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350C-Anniversary-Edition/Technology/CB350C-Special-Edition_HSTC-1120x623-pxl.png"
      }
    ]
  },
  {
    "code": "CB350C26",
    "name": "CB350C 2026",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 224000,
    "onRoadPrice": 258720,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350C-new2026/new/33216_Honda-CB350-C-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350C-new2026/new/CB350C-2026_meta-1.jpg",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350C-new2026/new/CB350C-2026_meta-1.jpg",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350C-new2026/new/CB350C-2026_meta-1.jpg"
      }
    ]
  },
  {
    "code": "CB350H",
    "name": "H'ness CB350",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 215500,
    "onRoadPrice": 248903,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350-Hness/cb350-hness-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350-Hness/Desktop/EMI-Calculator/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350-Hness/Desktop/EMI-Calculator/EMI-Calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/CB350-Hness/Desktop/EMI-Calculator/EMI-Calculator.png"
      }
    ]
  },
  {
    "code": "CB350RSN",
    "name": "CB350RS (New)",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 219500,
    "onRoadPrice": 253523,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350rs-new2026/V5---33216_Honda-New-RS-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350rs-new2026/emi/33445_350-RS_EMI-Calculator_1038x638.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350rs-new2026/emi/33445_350-RS_EMI-Calculator_1038x638.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb350rs-new2026/emi/33445_350-RS_EMI-Calculator_1038x638.png"
      }
    ]
  },
  {
    "code": "CB350RS",
    "name": "CB350RS",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 350,
    "exShowroomPrice": 215500,
    "onRoadPrice": 248903,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350RS/CB350RS-brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350RS/EMI-Calculator/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350RS/EMI-Calculator/EMI-Calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB350RS/EMI-Calculator/EMI-Calculator.png"
      }
    ]
  },
  {
    "code": "CB500H",
    "name": "CB500 Hornet",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 500,
    "exShowroomPrice": 589000,
    "onRoadPrice": 680295,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/PP_CB500-Brochure-Size-75w-X-1333-in-Page--1-to-12__R5-MB7.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/360/new/CB500_Burgundy.png",
    "colours": [
      {
        "name": "Rebel Red Metallic",
        "hex": "#800020",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/360/new/CB500_Burgundy.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#800020",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/new/CB500_Black_Alloy-wheel.png"
      },
      {
        "name": "Pearl Deep ground Gray",
        "hex": "#000000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/new/CB500_Sliver_Alloy-wheel.png"
      },
      {
        "name": "Matt Steel Silver Metallic",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/cb500-bigwing/new/CB500_Sliver_Spoke-Wheel.png"
      }
    ]
  },
  {
    "code": "NX500",
    "name": "NX500 E-Clutch",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 500,
    "exShowroomPrice": 590000,
    "onRoadPrice": 681450,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx-500-E-Clutch/pdf/nx-500-E-Clutch_Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx-500-E-Clutch/calculator/emi-calculator-1038x638.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx-500-E-Clutch/calculator/emi-calculator-1038x638.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/nx-500-E-Clutch/calculator/emi-calculator-1038x638.png"
      }
    ]
  },
  {
    "code": "CB1000SP",
    "name": "CB1000 Hornet SP",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 1000,
    "exShowroomPrice": 1235900,
    "onRoadPrice": 1427465,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/hornet-1000-sp/pdf1/Hornet-1000SP_Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/hornet-1000-sp/EMI-Calculator-(3).png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/hornet-1000-sp/EMI-Calculator-(3).png",
    "colours": [
      {
        "name": "Matte Ballistic Black Metallic",
        "hex": "#1C1E21",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/hornet-1000-sp/EMI-Calculator-(3).png"
      }
    ]
  },
  {
    "code": "XL750",
    "name": "XL750 Transalp E-Clutch",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 750,
    "exShowroomPrice": 1099990,
    "onRoadPrice": 1270488,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/xl750-transalp-E-Clutch/pdf/XL750-Transalp-E-Clutch.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/xl750-transalp-E-Clutch/EMI-calculator/EMI-calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/xl750-transalp-E-Clutch/EMI-calculator/EMI-calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/xl750-transalp-E-Clutch/EMI-calculator/EMI-calculator.png"
      }
    ]
  },
  {
    "code": "CB750H",
    "name": "CB750 Hornet E-Clutch",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 750,
    "exShowroomPrice": 859500,
    "onRoadPrice": 992723,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB750-Hornet-E-Clutch/pdf/Hornet-750-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB750-Hornet-E-Clutch/calculator/calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB750-Hornet-E-Clutch/calculator/calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/CB750-Hornet-E-Clutch/calculator/calculator.png"
      }
    ]
  },
  {
    "code": "GOLDWING",
    "name": "Gold Wing Tour",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 1833,
    "exShowroomPrice": 3920000,
    "onRoadPrice": 4527600,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/gold-wing-tour/pdf/Goldwing-Brochure.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/gold-wing-tour/calculator/calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/gold-wing-tour/calculator/calculator.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Bigwing/gold-wing-tour/calculator/calculator.png"
      }
    ]
  },
  {
    "code": "CBR1000SP",
    "name": "CBR1000RR-R SP",
    "category": "BigBike",
    "division": "BigWing",
    "ccDisplacement": 1000,
    "exShowroomPrice": 2356000,
    "onRoadPrice": 2721180,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Cbr1000rr/pdf/103Ki---Fireblade_Brochure_LR.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Cbr1000rr/calculator/Pricing-1038x638.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Cbr1000rr/calculator/Pricing-1038x638.png",
    "colours": [
      {
        "name": "Grand Prix Red",
        "hex": "#CC0000",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/Cbr1000rr/calculator/Pricing-1038x638.png"
      }
    ]
  },
  {
    "code": "ACT110DLX",
    "name": "Activa 110",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 110,
    "exShowroomPrice": 78684,
    "onRoadPrice": 90880,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/2New-Combine-brochure-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/activa110/ProductEMICalculator/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Mat_Axis_Gray_Metallic.png",
    "colours": [
      {
        "name": "Mat Axis Gray Metallic",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Mat_Axis_Gray_Metallic.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Pearl_Igneous_Black.png"
      },
      {
        "name": "Pearl Precious White",
        "hex": "#EDEDED",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Pearl_Precious_White.png"
      },
      {
        "name": "Pearl Siren Blue",
        "hex": "#21222B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Pearl_Siren_Blue.png"
      },
      {
        "name": "Rebel Red Metallic",
        "hex": "#831F2B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa-110/360-color-images/Rebel_Red_Metallic.png"
      }
    ]
  },
  {
    "code": "ACT110ANN",
    "name": "Activa110 Anniversary Edition",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 110,
    "exShowroomPrice": 82500,
    "onRoadPrice": 95288,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa125-Anniversary-Edition/Brochure/activa110-anniversary-edition-1.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/product-banners/Activa110-Anniversary-Edition/mobile.jpg",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/activa110-anniversary/360/2/color-profile-1920-1392-black.png",
    "colours": [
      {
        "name": "Matte Steel Black Metallic.",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/activa110-anniversary/360/2/color-profile-1920-1392-black.png"
      }
    ]
  },
  {
    "code": "DIO110",
    "name": "Dio 110",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 110,
    "exShowroomPrice": 74930,
    "onRoadPrice": 86544,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/Brochure/dio110.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/dio110-emi-calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/colors/matte-axis-grey-metallic.png",
    "colours": [
      {
        "name": "Mat Axis Gray Metallic",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/colors/matte-axis-grey-metallic.png"
      },
      {
        "name": "Mat Marvel Blue",
        "hex": "#0666b0",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/colors/matte-marvel-blue-metallic_25.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/colors/pearl-igneous-black.png"
      },
      {
        "name": "Pearl Igneous Black + Pearl Deep Ground Gray",
        "hex": "#A39CAF",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio-110/colors/pearl-igneous-black-deep-ground-grey.png"
      }
    ]
  },
  {
    "code": "ACT125",
    "name": "Activa 125",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 94422,
    "onRoadPrice": 109057,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Brochure/2New-Combine-brochure-for-website.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/motorcycle/PLP-images/Activa-125.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Mat_Axis_Gray_Metallic_Activa125_OBD2B.png",
    "colours": [
      {
        "name": "Mat Axis Gray Metallic",
        "hex": "#39383E",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Mat_Axis_Gray_Metallic_Activa125_OBD2B.png"
      },
      {
        "name": "Pearl Deep Ground Gray",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Pearl_Deep_Ground_Gray_Activa125_OBD2B.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Pearl_Igneous_Black_Activa125_OBD2B.png"
      },
      {
        "name": "Pearl Precious White",
        "hex": "#EDEDED",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Pearl_Precious_White_Activa125_OBD2B.png"
      },
      {
        "name": "Pearl Siren Blue",
        "hex": "#21222B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/activa-125/Colours/Pearl_Siren_Blue_Activa125_OBD2B.png"
      }
    ]
  },
  {
    "code": "ACT125ANN",
    "name": "Activa125 Anniversary Edition",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 97500,
    "onRoadPrice": 112613,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa125-Anniversary-Edition/Calculator/activa125_aniversary_edition.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Activa125-Anniversary-Edition-optimze/ProductEMICalculator/Price-Page-1038x638px.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa125-Anniversary-Edition/360/blue/Honda-Activa-125-Color-side-shot-2.png",
    "colours": [
      {
        "name": "Pearl Siren Blue",
        "hex": "#194C75",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/Activa125-Anniversary-Edition/360/blue/Honda-Activa-125-Color-side-shot-2.png"
      }
    ]
  },
  {
    "code": "DIO125",
    "name": "Dio 125",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 96749,
    "onRoadPrice": 111745,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/Brochure/dio125.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Dio-125/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-5.png",
    "colours": [
      {
        "name": "Mat Marvel Blue Metallic",
        "hex": "#0065ac",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-5.png"
      },
      {
        "name": "Imperial Red",
        "hex": "#a62d30",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-3.png"
      },
      {
        "name": "Pearl Deep Ground Gray (Stripe)",
        "hex": "#afb0ae",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-2.png"
      },
      {
        "name": "Pearl Sports Yellow",
        "hex": "#e5b71e",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-4.png"
      },
      {
        "name": "Pearl Igneous Black",
        "hex": "#282828",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/dio125/color/dio125_HSmart-6.png"
      }
    ]
  },
  {
    "code": "DIO125X",
    "name": "Dio125 X-Edition",
    "category": "Scooter",
    "division": "RedWing",
    "ccDisplacement": 125,
    "exShowroomPrice": 99500,
    "onRoadPrice": 114923,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Dio125-X-Edition/pdf/3_Dio-Xedition-brochure-2-01.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Dio125-X-Edition/ProductEMICalculator/Honda-Dio-125-_-Special-Edition-_-360Dgr_1-_-1038-x-638px.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Dio125-X-Edition/ProductEMICalculator/Honda-Dio-125-_-Special-Edition-_-360Dgr_1-_-1038-x-638px.png",
    "colours": [
      {
        "name": "Standard",
        "hex": "#1E293B",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/new_asset_compressed/Scooter/Dio125-X-Edition/ProductEMICalculator/Honda-Dio-125-_-Special-Edition-_-360Dgr_1-_-1038-x-638px.png"
      }
    ]
  },
  {
    "code": "ADV160",
    "name": "ADV 160",
    "category": "Scooter",
    "division": "BigWing",
    "ccDisplacement": 160,
    "exShowroomPrice": 165000,
    "onRoadPrice": 190575,
    "brochureUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/ADV160--Brochure-R5-1.pdf",
    "listingImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/EMI-Calculator.png",
    "detailImageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/360/blue/Honda-ADV-160-Scooter-ATHLETIC-BLUE-METALLIC.png",
    "colours": [
      {
        "name": "Athletic Blue Metallic",
        "hex": "#00268C",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/360/blue/Honda-ADV-160-Scooter-ATHLETIC-BLUE-METALLIC.png"
      },
      {
        "name": "Pearl Deep Ground Gray",
        "hex": "#00268C",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/360/deep-grey/Honda-ADV-160-Scooter-PEARL-DEEP-GROUND-GRAY.png"
      },
      {
        "name": "Mat Axis Gray Metallic",
        "hex": "#b3b3b3",
        "imageUrl": "https://edge.sitecorecloud.io/hondamotorc388f-hmsi8ece-prodb777-e813/media/Project/HONDA2WI/honda2wheelersindia/scooter/adv160-new/360/grey/Honda-ADV-160-Scooter-MAT-AXIS-GREY-METALLIC.png"
      }
    ]
  }
];

export async function seedHondaCatalog(prisma: PrismaClient) {
  const redWing = await prisma.modelGroup.upsert({
    where: { name: "RedWing" },
    update: { status: "Active" },
    create: { name: "RedWing", quotePrefix: "RWQ", status: "Active" },
  });

  const bigWing = await prisma.modelGroup.upsert({
    where: { name: "BigWing" },
    update: { status: "Active" },
    create: { name: "BigWing", quotePrefix: "BWQ", status: "Active" },
  });

  let vehiclesUpserted = 0;
  let colourLinksUpserted = 0;

  for (const item of HONDA_2WHEELERS_CATALOG) {
    const modelGroupId = item.division === "BigWing" ? bigWing.id : redWing.id;

    const existing = await prisma.vehicle.findUnique({ where: { code: item.code } });
    const vehicle = await prisma.vehicle.upsert({
      where: { code: item.code },
      update: {
        name: item.name,
        category: item.category,
        modelGroupId,
        ccDisplacement: item.ccDisplacement,
        brochureUrl: item.brochureUrl ?? existing?.brochureUrl ?? null,
        listingImageUrl: item.listingImageUrl,
        detailImageUrl: item.detailImageUrl,
        status: "Active",
      },
      create: {
        code: item.code,
        name: item.name,
        category: item.category,
        modelGroupId,
        exShowroomPrice: item.exShowroomPrice,
        onRoadPrice: item.onRoadPrice,
        ccDisplacement: item.ccDisplacement,
        brochureUrl: item.brochureUrl,
        listingImageUrl: item.listingImageUrl,
        detailImageUrl: item.detailImageUrl,
        status: "Active",
      },
    });
    vehiclesUpserted++;

    for (const c of item.colours) {
      const colour = await prisma.colour.upsert({
        where: { name: c.name },
        update: { hex: c.hex, status: "Active" },
        create: { name: c.name, hex: c.hex, status: "Active" },
      });

      await prisma.vehicleColour.upsert({
        where: { vehicleId_colourId: { vehicleId: vehicle.id, colourId: colour.id } },
        update: { colourImageUrl: c.imageUrl },
        create: {
          vehicleId: vehicle.id,
          colourId: colour.id,
          colourImageUrl: c.imageUrl,
        },
      });
      colourLinksUpserted++;
    }
  }

  return { vehiclesUpserted, colourLinksUpserted };
}

if (require.main === module) {
  const prisma = new PrismaClient();
  seedHondaCatalog(prisma)
    .then((res) => {
      console.log("Honda 2Wheelers catalog synced:", res);
    })
    .catch((err) => {
      console.error("Failed to seed Honda 2Wheelers catalog:", err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
