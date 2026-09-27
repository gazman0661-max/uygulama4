import 'package:flutter/material.dart';
import '../models/site_project.dart';
import 'auto_repair_form_screen.dart';
import 'bakery_form_screen.dart';
import 'beauty_salon_form_screen.dart';
import 'bio_link_form_screen.dart';
import 'boutique_hotel_form_screen.dart';
import 'business_card_form_screen.dart';
import 'car_wash_form_screen.dart';
import 'cleaning_company_form_screen.dart';
import 'clinic_form_screen.dart';
import 'dentist_form_screen.dart';
import 'dietitian_form_screen.dart';
import 'driving_school_form_screen.dart';
import 'electrician_form_screen.dart';
import 'fitness_form_screen.dart';
import 'florist_form_screen.dart';
import 'furniture_decor_form_screen.dart';
import 'generic_business_form_screen.dart';
import 'handyman_form_screen.dart';
import 'kafe_form_screen.dart';
import 'kindergarten_form_screen.dart';
import 'kuafor_form_screen.dart';
import 'lawyer_form_screen.dart';
import 'makeup_artist_form_screen.dart';
import 'massage_spa_form_screen.dart';
import 'moving_company_form_screen.dart';
import 'musician_dj_form_screen.dart';
import 'personal_trainer_form_screen.dart';
import 'pet_grooming_form_screen.dart';
import 'photographer_form_screen.dart';
import 'portfolio_form_screen.dart';
import 'real_estate_form_screen.dart';
import 'restaurant_form_screen.dart';
import 'tailor_form_screen.dart';
import 'veterinarian_form_screen.dart';

/// Önizleme ekranındaki "Düzenle" butonunun kullandığı yönlendirici
/// (bkz. preview_screen.dart > _openEditForm).
///
/// [kind] o an ekrandaki slotu üreten formun türü (AppState.qtCurrentKind).
/// [initialData] o formun daha önce kaydedilmiş ham alan değerleri
/// (AppState.qtFormData) — form ekranı bunu initState'te kendi alanlarına
/// geri yazar (bkz. her form ekranındaki _restoreFromInitialData).
///
/// `ProjectKind.site` (Builder Pro / eski kayıtlar) ve `ProjectKind.qrCode`
/// (QR üretici, bir "form doldur -> site" akışı değil) için form tabanlı
/// bir düzenleme ekranı YOKTUR — null döner, çağıran taraf bunu ele alıp
/// kullanıcıya "bu site formdan düzenlenemiyor" gibi bir mesaj gösterir.
Widget? formScreenForKind(
  ProjectKind kind, {
  Map<String, dynamic>? initialData,
  bool isEditing = false,
}) {
  switch (kind) {
    case ProjectKind.autoRepair:
      return AutoRepairFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.bakery:
      return BakeryFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.beautySalon:
      return BeautySalonFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.bioLink:
      return BioLinkFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.boutiqueHotel:
      return BoutiqueHotelFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.businessCard:
      return BusinessCardFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.carWash:
      return CarWashFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.cleaningCompany:
      return CleaningCompanyFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.clinic:
      return ClinicFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.dentist:
      return DentistFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.dietitian:
      return DietitianFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.drivingSchool:
      return DrivingSchoolFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.electrician:
      return ElectricianFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.fitness:
      return FitnessFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.florist:
      return FloristFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.furnitureDecor:
      return FurnitureDecorFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.genericBusiness:
      return GenericBusinessFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.handyman:
      return HandymanFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.kafe:
      return KafeFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.kindergarten:
      return KindergartenFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.kuafor:
      return KuaforFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.lawyer:
      return LawyerFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.makeupArtist:
      return MakeupArtistFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.massageSpa:
      return MassageSpaFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.movingCompany:
      return MovingCompanyFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.musicianDj:
      return MusicianDjFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.personalTrainer:
      return PersonalTrainerFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.petGrooming:
      return PetGroomingFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.photographer:
      return PhotographerFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.portfolio:
      return PortfolioFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.realEstate:
      return RealEstateFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.restaurant:
      return RestaurantFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.tailor:
      return TailorFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.veterinarian:
      return VeterinarianFormScreen(initialData: initialData, isEditing: isEditing);
    case ProjectKind.site:
    case ProjectKind.qrCode:
      return null;
  }
}
